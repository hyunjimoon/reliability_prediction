functions{
    real failure_form(real phi, real age){
        return (pow(exp(phi), age) - 1)/(exp(phi) - 1);
    } 
}

data {
    int N;
    real complexity;
    real<lower=0,upper=1> age;
    real relative_displacement;
    int engine_count;
    
}

generated quantities{
    real<lower=1> phi = normal_rng(10, 5);
    real alpha = normal_rng(1.5, 1);
    real beta = normal_rng(0, 0.5);
    real gamma = normal_rng(0, 1);
    real delta = normal_rng(0, 0.5);
    real eta = normal_rng(0, 2);

    real early = complexity * alpha + beta * log(relative_displacement);
    real wear = complexity * engine_count * gamma + delta * log(relative_displacement);
    real lambda = early * failure_form(phi, -age+1) + wear * failure_form(phi, age) + eta;
    int y[N];
    for(n in 1:N){
        y[n] = poisson_rng(exp(lambda));
    }
}