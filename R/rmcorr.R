#' Calculate the repeated measures correlation coefficient.
#' 
#' @param participant A variable giving the subject name/id for each observation.
#' @param measure1 A numeric variable giving the observations for one measure.
#' @param measure2 A numeric variable giving the observations for the second measure.
#' @param dataset The data frame containing the variables.
#' @param CIs The method of calculating confidence intervals.
#' @param nreps The number of resamples to take if bootstrapping.
#' @param bstrap.out Determines if the output include the bootstrap resamples.
#' @return A list with class "rmc" containing the following components.
#' \item{r}{the value of the repeated measures correlation coefficient.}
#' \item{df}{the degrees of freedom}
#' \item{p}{the p-value for the repeated measures correlation coefficient.}
#' \item{CI}{the 95\% confidence interval for the repeated measures correlation coefficient.}
#' \item{model}{the multiple regression model used to calculate the correlation coefficient.}
#' \item{resamples}{the bootstrap resampled correlation values.}
#' @seealso \code{\link{plot.rmc}}
#' @examples
#' ## Bland Altman 1995 data
#' rmcorr(Subject, PacO2, pH, bland1995)
#' @export

rmcorr <- function(participant, measure1, measure2, dataset, 
                   CIs = c("analytic", "bootstrap"), 
                   nreps = 100, bstrap.out = F) {
    
    options(contrasts = c("contr.sum", "contr.poly"))
    
    args <- as.list(match.call())
    
    Participant <- eval(args$participant, dataset)
    if (class(Participant) == "character"){
        Participant <- get(Participant, dataset)
    }
    Measure1 <- eval(args$measure1, dataset)
    if (class(Measure1) == "character"){
        Measure1 <- get(Measure1, dataset)
    }
    Measure2 <- eval(args$measure2, dataset)
    if (class(Measure2) == "character"){
        Measure2 <- get(Measure2, dataset)
    }
    
    
    if (!is.factor(Participant)) 
    {
        Participant <- factor(Participant)
        warning(paste("'", args$participant, "' coerced into a factor", sep = ""))
    }
    
    if (!is.numeric(Measure1) || !is.numeric(Measure2))
        stop("'Measure 1' and 'Measure 2' must be numeric")
    
    #check for missing values
    newdat <- stats::na.omit(data.frame(Participant, Measure1, Measure2))
    Participant <- newdat$Participant
    Measure1 <- newdat$Measure1
    Measure2 <- newdat$Measure2
    
    CIs <- match.arg(CIs)
    
    lmmodel <- stats::lm(Measure2 ~ Participant + Measure1)
    lmslope <- stats::coef(lmmodel)["Measure1"]
    errordf <- lmmodel$df.residual
    
    # Direction of correlation based on whether slope is positive or negative  
    corrsign <- sign(lmslope)  
    
    # Drop each term for Type III sums of squares
    type3rmcorr <- stats::drop1(lmmodel, ~., test="F" )
    SSFactor <- type3rmcorr$'Sum of Sq'[3] 
    SSresidual <- type3rmcorr$RSS[1]
    
    #correlation coefficient
    rmcorrvalue <- as.numeric(corrsign * sqrt(SSFactor / (SSFactor + SSresidual)))
    
    # Pvalue and confidence intervals
    pvalue <- type3rmcorr$'Pr(>F)'[3]
    
    #analytic
    resamples <- NULL
    if (CIs == "analytic"){
        rmcorrvalueCI <- psych::r.con(rmcorrvalue, errordf) 
    } else if (CIs == "bootstrap") {
        nsubs <- length(levels(Participant))
        if (!is.numeric(nreps)){stop("Specify the number of bootstrap resamples to take")}
        cor.reps <- numeric(nreps)
        
        for (i in 1:nreps){
            bs.1 <- NULL
            bs.2 <- NULL
            
            for (j in 1:nsubs) {
                subdata <- which(Participant==levels(Participant)[j])
                resamp <- sample(subdata,length(subdata),replace=T)
                bs.1 <- c(bs.1,Measure1[resamp])
                bs.2 <- c(bs.2,Measure2[resamp])
            }
            
            bs.Part <- Participant
            repmodel<-stats::lm(bs.1 ~ bs.Part + bs.2)
            repslope <- stats::coef(repmodel)["bs.2"]
            errordf <- repmodel$df.residual
            repsign <- sign(repslope)  
            
            type3rmcorr<-stats::drop1(repmodel, ~., test="F" )
            SSFactor<-type3rmcorr$'Sum of Sq'[3] 
            SSresidual<-type3rmcorr$RSS[1]
            
            cor.reps[i] <- as.numeric(repsign*sqrt(SSFactor/(SSFactor+SSresidual)))
        }
        rmcorrvalueCI <- stats::quantile(cor.reps,probs=c(.025,.975))
        resamples <- cor.reps
    }
    
    
    
    rmoutput <- list(r = rmcorrvalue, df = errordf, p = pvalue, 
                     CI = rmcorrvalueCI, model = lmmodel, 
                     vars = as.character(c(args$participant,args$measure1,args$measure2)))
    if (bstrap.out) {rmoutput$resamples <- resamples}
    class(rmoutput) <- "rmc"
    return (rmoutput)
} 


#' Print the results of a repeated measures correlation
#' 
#' @param x An object of class "rmc", a result of a call to rmcorr.
#' @param ... additional arguments to \code{\link[base]{print}}.
#' @seealso \code{\link{rmcorr}}
#' @examples
#' ## Bland Altman 1995 data
#' blandrmc <- rmcorr(Subject, PacO2, pH, bland1995)
#' blandrmc
#' @export


print.rmc <- function(x, ...) {
    cat("\nRepeated measures correlation\n\n")
    cat("r\n")
    cat(x$r)
    cat("\n\ndegrees of freedom\n")
    cat(x$df)
    cat("\n\np-value\n")
    cat(x$p)
    cat("\n\n95% confidence interval\n")
    cat(x$CI)
    
}   
    
    