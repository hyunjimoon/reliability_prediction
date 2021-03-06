#setwd("C:/Users/serim/Documents/GitHub/reliability_prediction")

source(file.path(getwd(), "impute/mice_imputation.R"))
scriptDir <- getwd()
library(rstan)
library(ggplot2)
library(scales)

model_DMsep <- stan_model(file.path(getwd(), "optimize/step1/DMsep_5param.stan"), verbose = FALSE) #approx_deterioration_matrix

mice_imp <- generateMice()
imputed_data<- complete(mice_imp, 1)

imputed_data_gp <- read.csv("data/y_pred_5var.csv")[,-1]
imputed_data$y_data <- unlist(c(imputed_data_gp))


  #################################### DM_sep
# original policy (wihtout pm)
n_state = 3
initial_state = 1

generate_state_matrix <- function(data, n){
  #state <- cut(data, breaks=c(0, 80, 160, max(data)), labels=1:n, include.lowest = TRUE)
  state <- cut(data, breaks=quantile(data,c(0,1/3,2/3,1)), labels=1:n, include.lowest = TRUE)
  state<-as.numeric(state)
  matrix(state,nrow=31)
}

state_matrix <- generate_state_matrix(imputed_data$y_data, n_state)
states <- as.vector(t(state_matrix)) #[imputed_data$engine_ind == engine_type] shiptype -> year
onehot <- list()
# one-hot encode per-data state to vector
for(i in 1:length(states)){
  t_tmp <- rep(0, len=n_state)
  t_tmp[states[i]] <- 1
  onehot[[i]] <- t_tmp
}

onehot_array <- aperm(array(unlist(onehot),c(n_state, length(onehot)))) # array() fills column-wise first
set.seed(210106)

iter=1000

MSE_df<-data.frame(index=rep(0,iter),test_MSE=rep(0,iter),p=rep(0,iter),q=rep(0,iter),train_MSE=rep(0,iter),rate1=rep(0,iter),rate2=rep(0,iter),rate3=rep(0,iter))
D_array <- array(0, dim=c(iter,4,3,3))
ship_ind_df<-matrix(0,nrow=iter,ncol=5)

for (i in 1:iter){
  test_ship_ind= sort(sample(1:99,5)) #c(17,20,24,77,82)
  ship_ind_df[i,]=test_ship_ind
  test_ind=c(sapply(test_ship_ind,function(x) (x-1)*31+(1:31)))
  train_data <- onehot_array[-test_ind, ]
  test_data <- onehot_array[test_ind, ]
  opt_data <- list(N= dim(train_data)[1], n_state=n_state, state_obs=train_data, time_obs=imputed_data$age_ind[-test_ind], initial_state=initial_state)
  
  res <- optimizing(model_DMsep, opt_data, iter = 2000, verbose = TRUE,hessian = TRUE, history_size=10, init = list(rate=array(c(0.5,0.5,0.5,0.5,0.1,0.1,0.1,0.1,0.5,0.5,0.5,0.5), dim = c(4, 3))))
  
  predicted_state<-matrix(0,nrow=31,ncol=3)
  DM_pow<-array(0,dim=c(31,3,3))
  
  for (t in 1:31){
    for (k in 1:3){
      for (j in 1:3){
        DM_pow[t,k,j]=res$par[paste0("DM_pow[",t,",",k,",", j,"]")]
      }
    }
    predicted_state[t,]=DM_pow[t,,]%*%c(1,0,0)
  }
  MSE_df[i,3]=res$par["p"]
  MSE_df[i,4]=res$par["q"]
  
  for (era in 1:4){
    D <- matrix(as.vector(unlist(lapply(1:n_state, function(row){lapply(1:n_state, function(col){res$par[paste0("D[",era,",",row,",",col,"]")]})}))), nrow=3, byrow=T)
    D_array[i,era,,]=D
  }
  MSE_df[i,6]=res$par["rate[3,1]"]
  MSE_df[i,7]=res$par["rate[3,2]"]
  MSE_df[i,8]=res$par["rate[3,3]"]
  
  SSE_total = rep(0,nrow=99*31)
  for (ind in 1:(99*31)){
    SSE_total[ind]=sum((onehot_array[ind,]-predicted_state[(ind-1)%%31+1,])^2)
  }
  MSE_df[i,1]=i
  MSE_df[i,2]=sum(SSE_total[test_ind])/5
  MSE_df[i,5]=sum(SSE_total[-test_ind])/94
  
  print(paste0(i,"th iteration finished"))
}

par(mfrow=c(1,1))
hist(MSE_df$test_MSE,breaks=100,main="test MSE",xlab="test MSE")
hist(MSE_df$train_MSE,breaks=100,main="train MSE",xlab="train MSE")
#hist(MSE_df$r,breaks=100,main="r",xlab="r")

par(mfrow=c(3,3))
for(era in 1:4){
  for(i in 1:3){
    for(j in 1:3){
    hist(D_array[,era,i,j],breaks=100,main=paste0("Histogram of D[",i,",",j,"] of Era ", era),xlab=paste0("D[",i,",",j,"]"))
   }
  }
}

##ggplot(data.frame(p=rate_array[, 3, 3], two=D_array[,3,2,2]), aes(x=p, y=two)) + geom_point()

############################## 
##############################
# Debug code

rate<-matrix(0,nrow=4,ncol=3)

for (era in 1:4){
  D <- matrix(as.vector(unlist(lapply(1:n_state, function(row){lapply(1:n_state, function(col){res$par[paste0("D[",era,",",row,",",col,"]")]})}))), nrow=3, byrow=T)
  for(j in 1:3){
    rate[era,j] <- res$par[paste0("rate[", era,",", j,"]")]
  }
  h_ <- hist(rate[era,], breaks=50)
  print(h_$counts * h_$breaks)
  print(paste0("Era:",era))
  print(D)
}

predicted_state<-matrix(0,nrow=31,ncol=3)
DM_pow<-array(0,dim=c(31,3,3))

for (t in 1:31){
  for (i in 1:3){
    for (j in 1:3){
      DM_pow[t,i,j]=res$par[paste0("DM_pow[",t,",",i,",", j,"]")]
    }
  }
  predicted_state[t,]=DM_pow[t,,]%*%c(1,0,0)
}

observed_count = sapply(1:3,function(i) apply(state_matrix,1,function(x) sum(x==i)))
observed_prop=t(apply(observed_count,1,function(x) x/sum(x)))
observed_scaled_state = exp(exp(exp(observed_prop)))/10
observed_scaled_state = t(apply(observed_scaled_state,1,function(x) x/sum(x)))
scaled_state=exp(exp(exp(predicted_state)))/10
scaled_state =  t(apply(scaled_state,1,function(x) x/sum(x)))

#plot(1,type="n",xlab="year",ylab="state",pch=19,cex=1,xlim=c(0,32),ylim=c(.5,3.5))


#for(i in rep(1:31,each=3)){
#  for (j in rep(1:3,31)){
#    points(i,j,pch=16,cex=4,col = rgb(red = 0, green = 0, blue = 1, alpha = 0.5))
#  }
#}

ship_observed_state = data.frame(ship_id=rep(1:99,31),time=factor(rep(1:31,each=99)),state=states)
total_count_df=data.frame(time=factor(rep(1:31,3)),states=factor(rep(1:3,each=31)),observed=c(observed_count),predicted=c(predicted_state)*99)
test_count_df = data.frame(time=rep(1:31,5),observed=c(state_matrix[,test_ship_ind]),ship_ind=factor(rep(test_ship_ind,each=31)),predicted_max=rep(apply(predicted_state,1,which.max),5))

legend_size = 5

ggplot(total_count_df, aes(x = time, y = states)) +
  geom_point(aes(colour="observed", size = observed),alpha=1) +
  geom_point(aes(colour="predicted", size = predicted),alpha=0.4) +
  scale_size(breaks = c(-3:3), range = c(1,30)) +
  guides(
    size=guide_legend(override.aes = list(size = legend_size))
  ) 

total_df=data.frame(time=rep(1:31,3),states=rep(1:3,each=31),observed=c(observed_count),predicted=c(predicted_state)*99)

ggplot(test_count_df, aes(x = time, y = observed)) +
  geom_line(aes(colour=ship_ind),size=1.2) +
  coord_cartesian(ylim = c(0.5, 3.5)) +
  geom_point(aes(colour=ship_ind),size=3) +
  geom_point(data=total_df, aes(x=time,y=states, size = predicted),color="red",alpha=0.1) +
  scale_size(breaks = c(-3:3), range = c(1,30)) +
  guides(
    size=guide_legend(override.aes = list(size = legend_size))
  ) 

ggplot(test_count_df, aes(x = time, y = observed)) +
  geom_line(aes(colour=ship_ind),size=1.2) +
  coord_cartesian(ylim = c(0.5, 3.5)) +
  geom_point(aes(colour=ship_ind),size=3) +
  geom_point(aes(x=time,y=predicted_max),size=10,color="red",alpha=0.2)
  