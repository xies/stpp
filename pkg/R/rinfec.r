rinfec <- function(npoints=NULL,s.region,t.region,nsim=1,alpha,beta,gamma,maxrad,delta,s.distr="exponential",t.distr="uniform",h="step",p="min",recent="all",lambda=NULL,lmax=NULL,nx=100,ny=100,nt=1000,t0,inhibition=FALSE,...)
  {
  #
  # Simulate an infectious point process in a region D x T.
  #
  # Requires Splancs.
  #  
  # Arguments:
  #  
  #  npoints: number of points to simulate.
  #
  #  s.region: two columns matrix specifying polygonal region containing
  #        all data locations. If poly is missing, the unit square is
  #        considered.
  #
  #  t.region: vector containing the minimum and maximum values of
  #            the time interval.
  #  
  #  nsim: number of simulations to generate. Default is 1.
  #
  #  alpha: numerical value for the latent period.
  #
  #  beta: numerical value for the maximum infection rate.
  #
  #  gamma: numerical value for the infection period.
  #
  #  delta: spatial distance of inhibition.
  #
  #  maxrad: single value or 2-vector of spatial and temporal maximum
  #          radiation respectively. If single value, the same value is used
  #          for space and time.
  #
  #  s.distr: spatial distribution. Must be choosen among "uniform", "gaussian",
  #           "expoenntial" and "poisson".
  #
  #  t.distr: temporal distribution. Must be choosen among "uniform" and "exponential".  
  #
  #  h: infection rate function which depends on alpha, beta and delta.
  #     Must be choosen among "step" and "gaussian".
  #
  #  p: Must be choosen among "min", "max" and "prod".
  #
  #  recent:  If "all" consider all previous events. If is an integer, say N, 
  #           consider only the N most recent events. 
  #
  #  lambda: function or matrix define the intensity of a Poisson process if 
  #         s.distr is Poisson.
  #
  #  lmax: upper bound for the value of lambda.
  #
  #  nx,ny: define the 2-D grid on which the intensity is evaluated if s.distr 
  #        is Poisson.
  #
  #  nt: used to discretize time to compute the infection rate function.
  #
  #  t0: minimum time used to compute the infection rate function.
  #      Default in the minimum of t.region.
  #
  #  inhibition: Logical. If TRUE, an inhibition process is generated.
  #              Otherwise, it is a contagious process.
  #
  #
  # Value:
  #  pattern: list containing the points (x,y,t) of the simulated point
  #           process.
  #
  ##
  ## E. GABRIEL, 02/04/2007
  ##
  ## last modification: 20/10/2008
  ##
  ##

  if (is.null(npoints)) stop("please specify the number of points to generate")
  if (missing(s.region)) s.region <- matrix(c(0,0,1,1,0,1,1,0),ncol=2)
  if (missing(t.region)) t.region <- c(0,1)
  if (missing(t0)) t0 <- t.region[1]

  if (missing(maxrad)) maxrad <- c(0.05,0.05)
  maxrads <- maxrad[1]
  maxradt <- maxrad[2]

  if (missing(delta)) delta <- maxrads

  if (s.distr=="poisson")
    {
      s.grid <- make.grid(nx,ny,s.region)
      s.grid$mask <- matrix(as.logical(s.grid$mask),nx,ny)
      if (is.function(lambda))
        {
          Lambda <- lambda(as.vector(s.grid$X),as.vector(s.grid$Y),...)
          Lambda <- matrix(Lambda,ncol=ny,byrow=T)
        }
      if (is.matrix(lambda))
        {
          nx <- dim(lambda)[1]
          ny <- dim(lambda)[2]
          Lambda <- lambda
        }
      if (is.null(lambda))
        {
          Lambda <- matrix(npoints/areapl(s.region),ncol=ny,nrow=nx)
        }
      Lambda[s.grid$mask==FALSE] <- NaN
    }
  
  if (h=="step")
    {
      hk <- function(t,t0,alpha,beta,gamma)
        {
          res <- rep(0,length(t))
          mask <- (t <= t0+alpha+gamma) & (t >= t0+alpha)
          res[mask] <- beta
          return(res)
        }
    }

  if (h=="gaussian")
    {
      hk <- function(t,t0,alpha,beta,gamma)
        {
          t0 <- alpha+t0
          d <- gamma/8
          top <- beta*sqrt(2*pi)*d
#          res <- top*(1/(sqrt(2*pi)*d))*exp(-(((t-(t0+gamma/2))^2)/(2*d^2)))
          res <- top*dnorm(t,mean=t0+gamma/2,sd=d)
          return(res)
        }

      d <- gamma/8
      top <- beta*sqrt(2*pi)*d
      ug <- top*dnorm(0,mean=alpha+gamma/2,sd=d)
    }
  
  if (p=="min")
    {
      pk <- function(mu,recent)
        {
          if (recent=="all")
            res <- min(mu)
          else
            {
              if (is.numeric(recent))
                {
                  if(recent<=length(ITK))
                    res <- min(mu[(length(ITK)-recent+1):length(ITK)])
                  else
                    res <- min(mu)
                }
              else
                stop("'recent' must be numeric")
            }
          return(res)
        }
    }
  
  if (p=="max")
    {
      pk <- function(mu,recent)
        {
          if (recent=="all")
            res <- max(mu)
          else
            {
              if (is.numeric(recent))
                {
                  if(recent<=length(ITK))
                    res <- max(mu[(length(ITK)-recent+1):length(ITK)])
                  else
                    res <- max(mu)
                }
              else
                stop("'recent' must be numeric")
            }
          return(res)
        }
    }
    if (p=="prod")
    {
      pk <- function(mu,recent)
        {
          if (recent=="all")
            res <- prod(mu)
          else
            {
              if (is.numeric(recent))
                {
                  if(recent<=length(ITK))
                    res <- prod(mu[(length(ITK)-recent+1):length(ITK)])
                  else
                    res <- prod(mu)
                }
              else
                stop("'recent' must be numeric")
            }
          return(res)
        }
    }
  
  t.grid <- list(times=seq(t.region[1],t.region[2],length=nt),tinc=((t.region[2]-t.region[1])/(nt-1)))
  
  pattern <- list()
  ni <- 1
  while(ni<=nsim)
    {
      xy <- csr(n=1,poly=s.region)
      npts <- 1
      pattern.interm <- cbind(x=xy[1],y=xy[2],t=t0)
      Mu <- rep(0,nt)
      ti <- t0
      ITK <- iplace(t.grid$times,ti,t.grid$tinc)
      
      continue <- FALSE
      while(continue==FALSE)
        {
          while (npts<npoints)
            {
              ht <- hk(t=t.grid$times,t0=ti[npts],alpha=alpha,beta=beta,gamma=gamma)
#              ht <- ht/integrate(hk,lower=t.region[1],upper=t.region[2],subdivisions=nt,t0=t0,alpha=alpha,beta=beta,gamma=gamma)$value
              ht <- ht/(sum(ht)*t.grid$tinc)
              
              mu <- Mu+ht
              if (sum(mu)==0) 
                mu2 <- mu
              else
                mu2 <- mu/max(mu)
              
              if (t.distr=="uniform")
                tk <- ti[npts] + runif(1,min=0,max=maxradt)

              if (t.distr=="exponential")
                  tk <- ti[npts] + rexp(1,rate=1/maxradt)
#                  tk <- ti[npts]+rexp(1,rate=1/(sum(mu)*t.grid$tinc))

              if (tk>=t.region[2])
                {
                  npts <- npoints
                  continue <- TRUE
                }
              else
                {
                  itk <- iplace(t.grid$times,tk,t.grid$tinc)

                 if ((mu[itk]==0) || ((h=="gaussian") && (mu[itk]<ug)))
                   {
                     npts <- npoints
                     continue <- TRUE
                   }
                 else
                   {
                     uk <- runif(1)
                     Mu <- mu
                     if (inhibition==FALSE)
                       {
                         cont <- FALSE
                         while(cont==FALSE)
                           {
                             xpar <- pattern.interm[npts,1]
                             ypar <- pattern.interm[npts,2]

                             out <- TRUE
                             while(out==TRUE)
                               {
                                 if (s.distr=="uniform")
                                   {
                                     xp <- xpar+runif(1,min=-maxrads,max=maxrads)
                                     yp <- ypar+runif(1,min=-maxrads,max=maxrads)
                                   }
                                 if (s.distr=="gaussian")
                                   {
                                     xp <- xpar+rnorm(1,mean=0,sd=maxrads/2)
                                     yp <- ypar+rnorm(1,mean=0,sd=maxrads/2)
                                   }
                                 if (s.distr=="exponential")
                                   {
                                     xp <- xpar+sample(c(-1,1),1)*rexp(1,rate=1/maxrads)
                                     yp <- ypar+sample(c(-1,1),1)*rexp(1,rate=1/maxrads)
                                   }
                                 if (s.distr=="poisson")
                                   {
                                     if (is.null(lmax))
                                       lmax <- max(Lambda,na.rm=TRUE)
                                     retain.eq.F <- FALSE
                                     while(retain.eq.F==FALSE)
                                       {
                                         xy <- csr(poly=s.region,npoints=1)
                                         xp <- xy[1]
                                         yp <- xy[2]
                                         up <- runif(1)
                                         nix <- iplace(X=s.grid$x,x=xp,xinc=s.grid$xinc)
                                         niy <- iplace(X=s.grid$y,x=yp,xinc=s.grid$yinc)
                                         Up <- Lambda[nix,niy]/lmax
                                         retain <- up <= Up
                                         if ((retain==FALSE) || is.na(retain))
                                           retain.eq.F <- FALSE
                                         else
                                           retain.eq.F <- TRUE
                                      
                                       }
                                   }
                                 M <- inout(pts=rbind(c(xp,yp),c(xp,yp)),poly=s.region)
                                 if ((sqrt((xp - pattern.interm[npts,1])^2 + (yp - pattern.interm[npts,2])^2) < maxrads)) M <- c(M,M)
                                 if (sum(M)==4)
                                   out <- FALSE
                               }
                             
                             if (sqrt((xp - pattern.interm[npts,1])^2 + (yp - pattern.interm[npts,2])^2) < delta)
                               umax <- 1
                             else
                               umax <- mu2[itk]

                             if (uk < umax)
                               {
                                 npts <- npts+1
                                 ITK <- c(ITK,itk)
                                 ti <- c(ti,tk)
                                 pattern.interm <- rbind(pattern.interm,c(xp,yp,tk))
                                 cont <- TRUE
                               }
                           }                          
                       }
                     else
                       {
                         xy <- csr(n=1,poly=s.region)
                         xp <- xy[1]
                         yp <- xy[2]
                         
                         if (all((sqrt((xp - pattern.interm[,1])^2 + (yp - pattern.interm[,2])^2)) > delta))
                           umax <- 1
                         else
                           umax <- pk(mu=mu2[ITK],recent=recent)
                         if (uk < umax)
                           {
                             npts <- npts+1
                             ITK <- c(ITK,itk)
                             ti <- c(ti,tk)
                             pattern.interm <- rbind(pattern.interm,c(xp,yp,tk))
                           }
                       }
                   }
               }
            }
          continue <- TRUE
        }
      dimnames(pattern.interm) <- list(NULL,c("x","y","t"))
      if (nsim==1)
        {
          pattern <- pattern.interm
          ni <-  ni+1
        }
      else
        {
          pattern[[ni]] <- pattern.interm
          ni <- ni+1
        }
    }
  par(cex.lab=1.5,cex.axis=1.5)
  plot(t.grid$times,Mu,type="s",ylim=c(0,max(Mu)),lwd=2,xlab="t",ylab=expression(mu(t)))
  points(ti,Mu[ITK],pch=20,col=2,cex=1.5)
  invisible(return(list(xyt=pattern,s.region=s.region,t.region=t.region)))
}

 
