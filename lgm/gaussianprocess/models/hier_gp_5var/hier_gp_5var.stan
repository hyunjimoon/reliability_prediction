data {
  int<lower=1> N; //653
  int<lower=1> N_engines; //5
  int<lower=1> N_ships; //99
  int<lower=1> N_ages_obs; // 31
  int<lower=1> N_ages;// 31
  int<lower=1> ship_engine_ind[N_ships];
  int<lower=1,upper=99> ship_ind[N];
  int<lower=1> age_ind[N]; 
  vector[N] y; //
}
transformed data {
  real ages[N_ages];
  for (t in 1:N_ages)
    ages[t] = t;
}
parameters {
  matrix[N_ages,N_engines] GP_engine_std;
  matrix[N_ages,N_ships] GP_ship_std;
  vector[N_ages_obs] age_std;
  vector[N_ships] ship_std;
  vector[N_engines] engine_std;
  real<lower=0> tot_var;
  simplex[10] prop_var;
  real mu;
  real<lower=0> length_GP_engine;
  real<lower=0> length_GP_ship;
}
transformed parameters {
  matrix[N_ages,N_engines] GP_engine;
  matrix[N_ages,N_ships] GP_ship;

  vector[N_ages_obs] age_re;
  vector[N_ships] ship_re;
  vector[N_engines] engine_re;
  vector[10] vars;

  real sigma_age;
  real sigma_engine;
  vector[5] sigma_ship;

  real sigma_error_ship;

  real sigma_GP_engine;
  real sigma_GP_ship;

  vars = 10 * prop_var * tot_var;
  sigma_age = sqrt(vars[1]);
  sigma_engine = sqrt(vars[2]);
  for (i in 1:5){
    sigma_ship[i]=sqrt(vars[i+2]);
  }
  sigma_GP_engine = sqrt(vars[8]);
  sigma_GP_ship = sqrt(vars[9]);
  sigma_error_ship = sqrt(vars[10]);

  engine_re = sigma_engine * engine_std;
  age_re = sigma_age * age_std;
  ship_re = sigma_ship[ship_engine_ind] .* ship_std;
  
  {
    matrix[N_ages, N_ages] cov_engine; 
    matrix[N_ages, N_ages] cov_ship; 
    matrix[N_ages, N_ages] L_cov_engine; 
    matrix[N_ages, N_ages] L_cov_ship; 

    cov_engine = cov_exp_quad(ages, sigma_GP_engine, 
                                  length_GP_engine);
    cov_ship = cov_exp_quad(ages, sigma_GP_ship, 
                                  length_GP_ship);
    for (age in 1:N_ages) {
      cov_engine[age, age] = cov_engine[age, age] + 1e-6;
      cov_ship[age, age] = cov_ship[age, age] + 1e-6;
    }

    L_cov_engine = cholesky_decompose(cov_engine);
    L_cov_ship = cholesky_decompose(cov_ship);
    GP_engine = L_cov_engine * GP_engine_std; //f_engine
    GP_ship = L_cov_ship * GP_ship_std;       //f_ship
  }
}
model {
  vector[N] obs_mu;

  for (n in 1:N) {
    obs_mu[n] = mu 
              + age_re[age_ind[n]]                                 //fixed effects
              + engine_re[ship_engine_ind[ship_ind[n]]] 
              + ship_re[ship_ind[n]]   
              + GP_engine[age_ind[n],ship_engine_ind[ship_ind[n]]] //f_engine 
              + GP_ship[age_ind[n],ship_ind[n]];                   //f_ship
  }
  y ~ normal(obs_mu, sigma_error_ship); 

  to_vector(GP_engine_std) ~ normal(0, 1);
  to_vector(GP_ship_std) ~ normal(0, 1);
  age_std ~ normal(0, 1);
  ship_std ~ normal(0, 1);
  engine_std ~ normal(0, 1);
  mu ~ normal(.5, .5);
  tot_var ~ gamma(3, 3);
  length_GP_engine ~ weibull(30,8); // value?
  length_GP_ship ~ weibull(30,8);
}
generated quantities {
  // matrix[N_ages,N_ships] y_new;
  // matrix[N_ages,N_ships] y_new_pred;
  vector[N] obs_mu;

  for (n in 1:N) {
    obs_mu[n] = mu 
              + age_re[age_ind[n]]                                 //fixed effects
              + engine_re[ship_engine_ind[ship_ind[n]]] 
              + ship_re[ship_ind[n]]   
              + GP_engine[age_ind[n],ship_engine_ind[ship_ind[n]]] //f_engine 
              + GP_ship[age_ind[n],ship_ind[n]];                   //f_ship
  }
}