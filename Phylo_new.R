library(picante)
library(phyloseq)
library(ggplot2)
library(plyr)
library(gplots)
library(RColorBrewer)


# import the Phylogentic tree generates with fasttree in qiime #

setwd("~/Documents/01_PhD/01_Research/02_rare_Biosphere/Illumina_raw_data/raw_Lucas/Usearch/wo_Singletons/fastrees")


########################
# Tree doesn't contain all OTUs in species matrix #
# species matrix seems to be correct #

# check Tree!

######################


Tree<-read.tree("OTU97_woS_oB_0.tre")

# strip ">" and ">>" from tip.lables
Tree$tip.label<-sub(">+(\\w+)","\\1",Tree$tip.label)

#strip single quotation marks around tip.lables
Tree$tip.label<-sub("'(\\w+)'","\\1",Tree$tip.label)

# import corresponding community matrix 
setwd("~/Documents/01_PhD/01_Research/02_rare_Biosphere/R scripts")

OTUm<-as.matrix(read.table("OTUm.txt",sep="\t",header=T,stringsAsFactors=FALSE))

# import taxonomic information
OtuTAX<-read.table("OTU_woS_onlyBAC_wTax.txt",sep="\t",header=T,stringsAsFactors=F)

setwd("~/Documents/01_PhD/01_Research/02_rare_Biosphere/R_clean")
#import sample meta data
ID<-read.table("gbgID",header=TRUE)

# add "age" coloumn to DIV
ID$age[ID$DAT=="14Jun"]<-12
ID$age[ID$DAT=="28Jun"]<-26
ID$age[ID$DAT=="12Jul"]<-40

# order ID
ID$DIL<-factor(ID$DIL, levels=c("0","1","2","3","4","5","6","7","8","9","10","S"))

# order ID
ID<-ID[with(ID,order(age,Lake,DIL)),]

###### loop to test stability of metrics ####
#for (i in 1:10)  {
####

#create rarefied OTUmatrix (N=5092)

N<-5092
W<-which(rowSums(OTUm)>N)
OTUmr<-rrarefy(OTUm[c(W),],N)

#exclude 0 abundance species in rarefied dataset
OTUmr<-OTUmr[,-c(which(colSums(OTUmr)==0))]

# match species in each Tree with species present in OTUmr
prunedTree<-prune.sample(OTUmr, Tree)



########### calculate unifrac ##############

Phylo_obj <- phyloseq(otu_table(OTUmr, taxa_are_rows = F), phy_tree(prunedTree))
unifrac_dist <- UniFrac(Phylo_obj, weighted = F)
save(unifrac_dist, file = "unifrac_dist.RData")

########## plot metanmds #########

unifrac_nmds <- metaMDS(unifrac_dist)

# extract points for plotting
fitp <- data.frame( unifrac_nmds$points)

#join metadata
fitp$gbgID<-rownames(fitp)

fitp<-join(fitp,ID)
fitp$age <- as.factor(fitp$age)

find_hull <- function(df) df[chull(df$MDS1, df$MDS2), ]
hulls <- ddply(fitp[,c(1,2,6,9)], .(Lake, age), find_hull)
hulls$age <- as.factor(hulls$age)

ggplot(fitp,aes(x=MDS1,y=MDS2))+
  geom_point(data=fitp,aes(colour=Lake,shape=Lake,size=4))+
  geom_text(data=fitp,aes(colour=Lake,label=DIL,hjust=-0.7,size=4))+
  geom_polygon(data=hulls,aes(alpha=0.2,fill=Lake))+
  facet_wrap(~age)+
  theme_bw(base_size=15)+
  scale_colour_manual(values=c("orange","darkred","darkgreen","darkblue"))+
  scale_fill_manual(values=c("orange","darkred","darkgreen","darkblue"))+
  theme(legend.position="bottom")+
  guides(size=F,alpha=F)

ggplot(fitp,aes(x=MDS1,y=MDS2))+
  geom_point(data=fitp,aes(colour=age,shape=age,size=4))+
  geom_text(data=fitp,aes(colour=age,label=DIL,hjust=-0.7,size=4))+
  geom_polygon(data=hulls,aes(alpha=0.2,fill=age))+
  facet_wrap(~Lake)+
  theme_bw(base_size=15)+
  theme(legend.position="bottom")+
  guides(size=F,alpha=F)

############################################



#calculate psv, psr, pse

#### psv: phylogenetic species variability ####

# quantifies how phylogenetic relatedness decreases 
# the variance of a hypothetical unselected/neutral 
# trait shared by all species in a community. 
# bound between 0 and 1 (1 = max variability; all sp. unrelated)

#### psr: phylogenetic species richness ####

# psv x richness
# "scales" the richness (S) of the community by it's psv
# bound between 0 and S
# often strongly correlated to S 

#### psr: phylogenetic species eveness ####

# modified psv that incorporates abundance information
# bound between 0 and 1 (1 = copletely even community with star phylogeny)

psv.result<-psv(OTUmr, prunedTree)
psv.result$gbgID<-rownames(psv.result)

psr.result<-psr(OTUmr, prunedTree)
psr.result$gbgID<-rownames(psr.result)

pse.result<-pse(OTUmr, prunedTree)
pse.result$gbgID<-rownames(pse.result)

pd.result <- pd(OTUmr, prunedTree, include.root =F)
pd.result$gbgID<-rownames(pd.result)

pc.result <- psc(OTUmr, prunedTree)
pc.result$gbgID<-rownames(pc.result)

#mpd.result <- mpd(OTUmr, cophenetic(prunedTree))

psResult<-join(psv.result,ID,by="gbgID")
psResult<-join(psResult,psr.result,by="gbgID")
psResult<-join(psResult,pse.result,by="gbgID")
psResult<-join(psResult,pd.result,by="gbgID")
psResult<-join(psResult,pc.result,by="gbgID")

### corr

ggpairs(psResult[,c("PSVs","PSEs","PSR","PSCs","SR")])
#######

#if (i == 1) {psRes<-psResult}
#if (i > 1) { psRes <- cbind(psRes,psResult)}

#}

#ggpairs(psRes[,which(colnames(psRes) == "PSVs")])

########



# import BAC 
BM<-read.table("BMfull.txt",stringsAsFactors=F)
maxBMP<-ddply(BM, .(Lake,DIL), function(x) mean(x[with(x, order(-Cells)),][1:5,]$Cells))
colnames(maxBMP)<-c("Lake","DIL","Cells")

# average PD over three sampling dates
AVpsResult <- ddply(psResult , .(BOT,Lake,DIL), numcolwise(mean,na.rm=T))

maxBMP<-join(maxBMP,AVpsResult,by=c("Lake","DIL"))

# import and join Stability 
CV<-read.table("Stability_detr.txt",sep="\t")

maxBMP<-join(maxBMP,CV,by=c("Lake","DIL","BOT"))

############## maximum Yield ################

############# PSE ############# 
### changed from PSV to PSE as PSV is unstable (i.e. depends too much on the inclusion
### of rare species during rarefaction) # PSV is copied below
#####

##### glms ###

# glm model with undiluted ("0")
PSEglm<-glm(Cells ~ PSEs*Lake, data=maxBMP, family=gaussian())
summary(PSEglm)
par(mfrow=c(2,2))
plot(PSEglm)

# glm model without undiluted ("0")
PSEglm0<-glm(Cells ~ PSEs * Lake, data=maxBMP[maxBMP$DIL != "0",], family=gaussian())
summary(PSEglm0)
par(mfrow=c(2,2))
plot(PSEglm0)

##### predict ###

# predict results 
PSEpr <- data.frame(PSEs=unlist(by(maxBMP, maxBMP$Lake, with, 
                                     data.frame(x = seq(min(PSEs), max(PSEs), length = 100)))),
                     Lake=rep(levels(as.factor(maxBMP$Lake)),each=100))

preds <- predict(PSEglm, newdata = PSEpr, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSEpr$upr <- (preds$fit + (CI * preds$se.fit))
PSEpr$lwr <- (preds$fit - (CI * preds$se.fit))
PSEpr$fit <- (preds$fit)

# predict results 
PSEpr0 <- data.frame(PSEs=unlist(by(maxBMP[maxBMP$DIL != "0",], maxBMP[maxBMP$DIL != "0",]$Lake, with, 
                                   data.frame(x = seq(min(PSEs), max(PSEs), length = 100)))),
                    Lake=rep(levels(as.factor(maxBMP[maxBMP$DIL != "0",]$Lake)),each=100))

preds <- predict(PSEglm0, newdata = PSEpr0, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSEpr0$upr <- (preds$fit + (CI * preds$se.fit))
PSEpr0$lwr <- (preds$fit - (CI * preds$se.fit))
PSEpr0$fit <- (preds$fit)

# rsquares an p-values for each of the 8 models

SIG<- data.frame(Lake = levels(as.factor(maxBMP$Lake)), 
                 w0 = rep(c("w0", "wo0"),each=4),
                 p = NA,
                 r = NA)

for (k in 1:2 ) {
  for ( i in 1:4 ) {
    
    if (k == 1) { tempDF <- maxBMP} else {tempDF <- maxBMP[maxBMP$DIL != "0",]} 
    tempDF <- tempDF[tempDF$Lake == levels(as.factor(tempDF$Lake))[i],]
    LM <- lm(Cells ~ PSEs, data=tempDF)
    r <- summary(LM)$r.square
    f <- summary(LM)$fstatistic
    p <- pf(f[1],f[2],f[3],lower.tail=F)
    
    SIG[i+(k-1)*4,]$r <- r
    SIG[i+(k-1)*4,]$p <- p
    
  }
}

SIG$psig <- NA

for (l in 1:nrow(SIG)){
  if(SIG[l,]$p > 0.05) { SIG[l,]$psig <- "n.s."}
  if(SIG[l,]$p <= 0.1) { SIG[l,]$psig <- "."}
  if(SIG[l,]$p <= 0.05) { SIG[l,]$psig <- "*"}
  if(SIG[l,]$p <= 0.01) { SIG[l,]$psig <- "**"}
  if(SIG[l,]$p <= 0.001) { SIG[l,]$psig <- "***"}
  }

SIG$pos<-rep(c(4E6,3.5E6),each=4)


  ggplot(maxBMP,aes(x=PSEs,y=Cells,colour=Lake,shape=Lake))+
  geom_point(size=4,alpha=0.8)+
  geom_point(data=maxBMP[maxBMP$DIL == "0",],aes(x=PSEs,y=Cells,size=4),shape=1,size=9,colour="black")+
  facet_wrap(~Lake)+
  geom_line(data=PSEpr, aes(x=PSEs,y=fit),colour="black")+
  geom_line(data=PSEpr0, aes(x=PSEs,y=fit),colour="black",linetype="dashed")+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.10, y=pos,
    label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.10, y=pos,
    label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.145, y=pos,
    label=psig),colour="black",size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.145, y=pos,
    label=psig),colour="black",size=4,hjust=0)+
  geom_segment(aes(x=0.05,xend=0.09,y=3.9e6, yend=3.9e6),colour="black", linetype="solid")+
  geom_segment(aes(x=0.05,xend=0.09,y=3.4e6, yend=3.4e6),colour="black", linetype="dashed")+
  scale_y_continuous(limits = c(0, 4.5e6))+
  #scale_x_continuous(limits = c(0.1, 0.47))+
  theme_bw(base_size=15)+
  theme(legend.position="none")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species evenes", y="average maximum cell count",
       title="maximum yield vs phlyogenetic species evenness")



############ stability ############

##### glms ###

# glm model with undiluted ("0")
PSEglm<-glm(Stability ~ PSEs*Lake, data=maxBMP, family=gaussian())
summary(PSEglm)
#par(mfrow=c(2,2))
#plot(PSEglm)

# glm model without undiluted ("0")
PSEglm0<-glm(Stability ~ PSEs * Lake, data=maxBMP[maxBMP$DIL != "0",], family=gaussian())
summary(PSEglm0)
#par(mfrow=c(2,2))
#plot(PSEglm)

##### predict ###

# predict results 
PSEpr <- data.frame(PSEs=unlist(by(maxBMP, maxBMP$Lake, with, 
                                   data.frame(x = seq(min(PSEs), max(PSEs), length = 100)))),
                    Lake=rep(levels(as.factor(maxBMP$Lake)),each=100))

preds <- predict(PSEglm, newdata = PSEpr, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSEpr$upr <- (preds$fit + (CI * preds$se.fit))
PSEpr$lwr <- (preds$fit - (CI * preds$se.fit))
PSEpr$fit <- (preds$fit)

# predict results 
PSEpr0 <- data.frame(PSEs=unlist(by(maxBMP[maxBMP$DIL != "0",], maxBMP[maxBMP$DIL != "0",]$Lake, with, 
                                    data.frame(x = seq(min(PSEs), max(PSEs), length = 100)))),
                     Lake=rep(levels(as.factor(maxBMP[maxBMP$DIL != "0",]$Lake)),each=100))

preds <- predict(PSEglm0, newdata = PSEpr0, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSEpr0$upr <- (preds$fit + (CI * preds$se.fit))
PSEpr0$lwr <- (preds$fit - (CI * preds$se.fit))
PSEpr0$fit <- (preds$fit)

# rsquares an p-values for each of the 8 models

SIG<- data.frame(Lake = levels(as.factor(maxBMP$Lake)), 
                 w0 = rep(c("w0", "wo0"),each=4),
                 p = NA,
                 r = NA)

for (k in 1:2 ) {
  for ( i in 1:4 ) {
    
    if (k == 1) { tempDF <- maxBMP} else {tempDF <- maxBMP[maxBMP$DIL != "0",]} 
    tempDF <- tempDF[tempDF$Lake == levels(as.factor(tempDF$Lake))[i],]
    LM <- lm(Stability ~ PSEs, data=tempDF)
    r <- summary(LM)$r.square
    f <- summary(LM)$fstatistic
    p <- pf(f[1],f[2],f[3],lower.tail=F)
    
    SIG[i+(k-1)*4,]$r <- r
    SIG[i+(k-1)*4,]$p <- p
    
  }
}

SIG$psig <- NA

for (l in 1:nrow(SIG)){
  if(SIG[l,]$p > 0.1) { SIG[l,]$psig <- "n.s."}
  if(SIG[l,]$p <= 0.1) { SIG[l,]$psig <- "."}
  if(SIG[l,]$p <= 0.05) { SIG[l,]$psig <- "*"}
  if(SIG[l,]$p <= 0.01) { SIG[l,]$psig <- "**"}
  if(SIG[l,]$p <= 0.001) { SIG[l,]$psig <- "***"}
}

SIG$pos<-rep(c(12,10),each=4)


 ggplot(maxBMP,aes(x=PSEs,y=Stability,colour=Lake,shape=Lake))+
  geom_point(size=4,alpha=0.8)+
  geom_point(data=maxBMP[maxBMP$DIL == "0",],aes(x=PSEs,y=Stability,size=4),shape=1,size=9,colour="black")+
  facet_wrap(~Lake)+
  geom_line(data=PSEpr, aes(x=PSEs,y=fit),colour="black")+
  geom_line(data=PSEpr0, aes(x=PSEs,y=fit),colour="black",linetype="dashed")+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.08, y=pos,
                                           label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.08, y=pos,
                                            label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.126, y=pos,
                                           label=psig),colour="black",size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.126, y=pos,
                                            label=psig),colour="black",size=4,hjust=0)+
  geom_segment(aes(x=0.045,xend=0.07,y=11.8, yend=11.8),colour="black", linetype="solid")+
  geom_segment(aes(x=0.045,xend=0.07,y=9.8, yend=9.8),colour="black", linetype="dashed")+
  scale_y_continuous(limits = c(0, 14))+
 # scale_x_continuous(limits = c(0.04, 0.47))+
  theme_bw(base_size=15)+
  theme(legend.position="none")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species evenness", y="satbilty (1/CV)",
       title="stability vs phlyogenetic species  evenness ")






############# PSV #############


##### glms ###

# glm model with undiluted ("0")
PSVglm<-glm(Cells ~ PSVs*Lake, data=maxBMP, family=gaussian())
summary(PSVglm)
#par(mfrow=c(2,2))
#plot(PSVglm)

# glm model without undiluted ("0")
PSVglm0<-glm(Cells ~ PSVs * Lake, data=maxBMP[maxBMP$DIL != "0",], family=gaussian())
summary(PSVglm0)
#par(mfrow=c(2,2))
#plot(PSVglm)

##### predict ###

# predict results 
PSVpr <- data.frame(PSVs=unlist(by(maxBMP, maxBMP$Lake, with, 
                                   data.frame(x = seq(min(PSVs), max(PSVs), length = 100)))),
                    Lake=rep(levels(as.factor(maxBMP$Lake)),each=100))

preds <- predict(PSVglm, newdata = PSVpr, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSVpr$upr <- (preds$fit + (CI * preds$se.fit))
PSVpr$lwr <- (preds$fit - (CI * preds$se.fit))
PSVpr$fit <- (preds$fit)

# predict results 
PSVpr0 <- data.frame(PSVs=unlist(by(maxBMP[maxBMP$DIL != "0",], maxBMP[maxBMP$DIL != "0",]$Lake, with, 
                                    data.frame(x = seq(min(PSVs), max(PSVs), length = 100)))),
                     Lake=rep(levels(as.factor(maxBMP[maxBMP$DIL != "0",]$Lake)),each=100))

preds <- predict(PSVglm0, newdata = PSVpr0, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSVpr0$upr <- (preds$fit + (CI * preds$se.fit))
PSVpr0$lwr <- (preds$fit - (CI * preds$se.fit))
PSVpr0$fit <- (preds$fit)

# rsquares an p-values for each of the 8 models

SIG<- data.frame(Lake = levels(as.factor(maxBMP$Lake)), 
                 w0 = rep(c("w0", "wo0"),each=4),
                 p = NA,
                 r = NA)

for (k in 1:2 ) {
  for ( i in 1:4 ) {
    
    if (k == 1) { tempDF <- maxBMP} else {tempDF <- maxBMP[maxBMP$DIL != "0",]} 
    tempDF <- tempDF[tempDF$Lake == levels(as.factor(tempDF$Lake))[i],]
    LM <- lm(Cells ~ PSVs, data=tempDF)
    r <- summary(LM)$r.square
    f <- summary(LM)$fstatistic
    p <- pf(f[1],f[2],f[3],lower.tail=F)
    
    SIG[i+(k-1)*4,]$r <- r
    SIG[i+(k-1)*4,]$p <- p
    
  }
}

SIG$psig <- NA

for (l in 1:nrow(SIG)){
  if(SIG[l,]$p > 0.05) { SIG[l,]$psig <- "n.s."}
  if(SIG[l,]$p <= 0.1) { SIG[l,]$psig <- "."}
  if(SIG[l,]$p <= 0.05) { SIG[l,]$psig <- "*"}
  if(SIG[l,]$p <= 0.01) { SIG[l,]$psig <- "**"}
  if(SIG[l,]$p <= 0.001) { SIG[l,]$psig <- "***"}
}

SIG$pos<-rep(c(4E6,3.5E6),each=4)


ggplot(maxBMP,aes(x=PSVs,y=Cells,colour=Lake,shape=Lake))+
  geom_point(size=4,alpha=0.8)+
  geom_point(data=maxBMP[maxBMP$DIL == "0",],aes(x=PSVs,y=Cells,size=4),shape=1,size=9,colour="black")+
  facet_wrap(~Lake)+
  geom_line(data=PSVpr, aes(x=PSVs,y=fit),colour="black")+
  geom_line(data=PSVpr0, aes(x=PSVs,y=fit),colour="black",linetype="dashed")+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.16, y=pos,
                                           label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.16, y=pos,
                                            label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.26, y=pos,
                                           label=psig),colour="black",size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.26, y=pos,
                                            label=psig),colour="black",size=4,hjust=0)+
  geom_segment(aes(x=0.11,xend=0.14,y=3.9e6, yend=3.9e6),colour="black", linetype="solid")+
  geom_segment(aes(x=0.11,xend=0.14,y=3.4e6, yend=3.4e6),colour="black", linetype="dashed")+
  scale_y_continuous(limits = c(0, 4.5e6))+
  scale_x_continuous(limits = c(0.1, 0.47))+
  theme_bw(base_size=15)+
  theme(legend.position="bottom")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species variability", y="average maximum cell count",
       title="maximum yield vs phlyogenetic species variability")




############ stability ############

##### glms ###

# glm model with undiluted ("0")
PSVglm<-glm(Stability ~ PSVs*Lake, data=maxBMP, family=gaussian())
summary(PSVglm)
#par(mfrow=c(2,2))
#plot(PSVglm)

# glm model without undiluted ("0")
PSVglm0<-glm(Stability ~ PSVs * Lake, data=maxBMP[maxBMP$DIL != "0",], family=gaussian())
summary(PSVglm0)
#par(mfrow=c(2,2))
#plot(PSVglm)

##### predict ###

# predict results 
PSVpr <- data.frame(PSVs=unlist(by(maxBMP, maxBMP$Lake, with, 
                                   data.frame(x = seq(min(PSVs), max(PSVs), length = 100)))),
                    Lake=rep(levels(as.factor(maxBMP$Lake)),each=100))

preds <- predict(PSVglm, newdata = PSVpr, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSVpr$upr <- (preds$fit + (CI * preds$se.fit))
PSVpr$lwr <- (preds$fit - (CI * preds$se.fit))
PSVpr$fit <- (preds$fit)

# predict results 
PSVpr0 <- data.frame(PSVs=unlist(by(maxBMP[maxBMP$DIL != "0",], maxBMP[maxBMP$DIL != "0",]$Lake, with, 
                                    data.frame(x = seq(min(PSVs), max(PSVs), length = 100)))),
                     Lake=rep(levels(as.factor(maxBMP[maxBMP$DIL != "0",]$Lake)),each=100))

preds <- predict(PSVglm0, newdata = PSVpr0, type = "link", se.fit = TRUE)

CI <- 1.96 ## approx 95% CI
PSVpr0$upr <- (preds$fit + (CI * preds$se.fit))
PSVpr0$lwr <- (preds$fit - (CI * preds$se.fit))
PSVpr0$fit <- (preds$fit)

# rsquares an p-values for each of the 8 models

SIG<- data.frame(Lake = levels(as.factor(maxBMP$Lake)), 
                 w0 = rep(c("w0", "wo0"),each=4),
                 p = NA,
                 r = NA)

for (k in 1:2 ) {
  for ( i in 1:4 ) {
    
    if (k == 1) { tempDF <- maxBMP} else {tempDF <- maxBMP[maxBMP$DIL != "0",]} 
    tempDF <- tempDF[tempDF$Lake == levels(as.factor(tempDF$Lake))[i],]
    LM <- lm(Stability ~ PSVs, data=tempDF)
    r <- summary(LM)$r.square
    f <- summary(LM)$fstatistic
    p <- pf(f[1],f[2],f[3],lower.tail=F)
    
    SIG[i+(k-1)*4,]$r <- r
    SIG[i+(k-1)*4,]$p <- p
    
  }
}

SIG$psig <- NA

for (l in 1:nrow(SIG)){
  if(SIG[l,]$p > 0.1) { SIG[l,]$psig <- "n.s."}
  if(SIG[l,]$p <= 0.1) { SIG[l,]$psig <- "."}
  if(SIG[l,]$p <= 0.05) { SIG[l,]$psig <- "*"}
  if(SIG[l,]$p <= 0.01) { SIG[l,]$psig <- "**"}
  if(SIG[l,]$p <= 0.001) { SIG[l,]$psig <- "***"}
}

SIG$pos<-rep(c(12,10),each=4)


  ggplot(maxBMP,aes(x=PSVs,y=Stability,colour=Lake,shape=Lake))+
  geom_point(size=4,alpha=0.8)+
  geom_point(data=maxBMP[maxBMP$DIL == "0",],aes(x=PSVs,y=Stability,size=4),shape=1,size=9,colour="black")+
  facet_wrap(~Lake)+
  geom_line(data=PSVpr, aes(x=PSVs,y=fit),colour="black")+
  geom_line(data=PSVpr0, aes(x=PSVs,y=fit),colour="black",linetype="dashed")+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.08, y=pos,
                                           label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.08, y=pos,
                                            label=paste('r^2 ==', signif(r,2), sep=" ")),colour="black",parse=T,size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "w0",],aes( x=0.18, y=pos,
                                           label=psig),colour="black",size=4,hjust=0)+
  geom_text(data=SIG[SIG$w0 == "wo0",],aes( x=0.18, y=pos,
                                            label=psig),colour="black",size=4,hjust=0)+
  geom_segment(aes(x=0.045,xend=0.075,y=11.8, yend=11.8),colour="black", linetype="solid")+
  geom_segment(aes(x=0.045,xend=0.075,y=9.8, yend=9.8),colour="black", linetype="dashed")+
  scale_y_continuous(limits = c(0, 14))+
  scale_x_continuous(limits = c(0.04, 0.47))+
  theme_bw(base_size=15)+
  theme(legend.position="bottom")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species variability", y="satbilty (1/CV)",
       title="stability vs phlyogenetic species variability ")


#### Ecolog data #####

## NC ## (with number of carbon sources per plate, median response, OD > 0.2)
EPnc<-read.table("EPnc.txt",stringsAsFactors=F)

# remove the old diversity data
EPnc<-EPnc[,-c(6:13)]

#rename Plate to BOT
colnames(EPnc)[1]<-"BOT"

# add "age" coloumn to EPnc
EPnc$age[EPnc$DAT==614]<-12
EPnc$age[EPnc$DAT==628]<-26
EPnc$age[EPnc$DAT==712]<-40

# add "age" coloumn to psResult
psResult$age[psResult$DAT=="14Jun"]<-12
psResult$age[psResult$DAT=="28Jun"]<-26
psResult$age[psResult$DAT=="12Jul"]<-40

#join phylogenetic diversity data (psResult)

EPnc<-join(EPnc,psResult,by=c("BOT","age"))

## r ## (with average r from modeled OD curves, mean over plate)
EPmr<-read.table("EPmr.txt",stringsAsFactors=F)

# remove the old diversity data
EPmr<-EPmr[,-c(3:4,6:10,12)]

#rename Plate to BOT
colnames(EPmr)[1]<-"BOT"

# add "age" coloumn to EPmr
EPmr$age[EPmr$DAT==614]<-12
EPmr$age[EPmr$DAT==628]<-26
EPmr$age[EPmr$DAT==712]<-40

EPmr<-join(EPmr,psResult,by=c("BOT","age"))

ggplot(EPnc,aes(x=log(PSVs),y=NC,colour=Lake,shape=Lake))+
  geom_point(size=3,alpha=0.8)+
  facet_wrap(~age)+
  geom_line(data=EPnc,aes(x=log(PSVs),y=NC),stat="smooth",method="lm",se=F,size=2,linetype="dashed",alpha=0.6)+
  stat_smooth(data=EPnc,aes(x=log(PSVs),y=NC,group=1),
              method="lm",se=T,size=1,colour="black",fill = "grey", size = 2, alpha = 0.7)+
  theme_bw(base_size=15)+
  theme(legend.position="bottom")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species variability", y="1/CV",
       title="Phlyogenetic species variability and Stability")


summary(lm(NC ~ log(PSVs) + Lake, data=EPnc ))

ggplot(EPmr,aes(x=log(PSVs),y=mean.r,colour=Lake,shape=Lake))+
  geom_point(size=3,alpha=0.8)+
  facet_wrap(~age)+
  geom_line(data=EPmr,aes(x=log(PSVs),y=mean.r),stat="smooth",method="lm",se=F,size=2,linetype="dashed",alpha=0.6)+
  stat_smooth(data=EPmr,aes(x=log(PSVs),y=mean.r,group=1),
              method="lm",se=T,size=1,colour="black",fill = "grey", size = 2, alpha = 0.7)+
  theme_bw(base_size=15)+
  theme(legend.position="bottom")+
  scale_colour_manual(values=c("orange", "darkred",
                               "darkgreen","darkblue"))+
  labs(x="phylogenetic species variability", y="1/CV",
       title="Phlyogenetic species variability and Stability")


summary(lm(mean.r ~ log(PSVs) + Lake, data=EPmr ))


########################################################################
########################################################################
#visual the species distribution among samples

W<-which(ID$gbgID %in% row.names(OTUmr))

pdf(file="Spec_dist_phylo_r5_pruned.pdf",height=40, width=20,onefile=T)

par(mfrow=c(6,3))


Lake <- c("Botan", "Delsjön", "Lerum" ,"Surtesjön")
LakeCol <- c("orange", "darkred","darkgreen","darkblue")

# redefine prune.sample to not look for colnames but take list of OTUs
prune.sampleFR <- function (samp, phylo) 
{
  treeTaxa <- phylo$tip.label
  sampleTaxa <- samp
  trimTaxa <- setdiff(treeTaxa, sampleTaxa)
  if (length(trimTaxa) > 0) 
    drop.tip(phylo, trimTaxa)
  else phylo
}

  


for (i in ID$gbgID){
if (i %in% ID$gbgID[W]) {
  Title<-paste(ID[which(ID$gbgID==i),4],ID[which(ID$gbgID==i),5],
               ID[which(ID$gbgID==i),6],sep=" ")
  prunedTreeTemp<-prune.sampleFR(names(OTUmr[i,OTUmr[i,]>0]), prunedTree)
  plot(prunedTreeTemp,type="un",show.tip.label = FALSE,use.edge.length = FALSE)
  title(main=list(Title,cex=4),col.main=LakeCol[which(Lake == ID[which(ID$gbgID==i),4] )])
  tiplabels(tip = which(prunedTreeTemp$tip.label %in% names(which(OTUmr[i, ] >0))),
            pch = 19, cex = log(which(OTUmr[i, ] >0),base=10) ,col="red")
  
} else {plot(1, type="n", axes=F, xlab="", ylab="")
        text(x=1,"Sample\n missing \nfrom \nOTUmr5",cex=3)}
}

dev.off()

#####################################
# circular tree with famiiy assignments

Lake <- c("Botan", "Delsjön", "Lerum" ,"Surtesjön")
LakeCol <- c("orange", "darkred","darkgreen","darkblue")

# merge the species with the Taxa assignment (Class, Order, Family)
plotTips <- data.frame('OTUId' = prunedTree$tip.label)
plotTips <- merge(plotTips, OtuTAX[,c(1,4:6)], sort=F)

# lable unidentified OTUs
for (Col in 2:4) {
  plotTips[plotTips[,Col]=="",][Col] <- "unidentified"
}

# code same taxa as same color (recycled)
plotCol<-plotTips

for (i in 2:4) {
  Taxlev<-levels(as.factor(plotCol[,i]))
  plotCol[,i]<-match(plotCol[,i],Taxlev)  
}

# add shape code #21:25
PCH<-data.frame(col=sort(unique(plotCol[,4])), 
                pch=c(rep(21:24,each=24),rep(25,20)))




#define colour palett (recycled if more then 25 colours needed)
c25r5 <- rep(c("dodgerblue2","#E31A1C", "green4","#6A3D9A", "#FF7F00",
               "black","gold1","skyblue2","#FB9A99","palegreen2","#CAB2D6",
               "#FDBF6F","gray70", "khaki2","maroon","orchid1","deeppink1",
               "blue1","steelblue4","darkturquoise","green1","yellow4",
               "yellow3","darkorange4","brown"),5)


pdf(file="Spec_dist_phylo_Class_pruned.pdf",height=40, width=20,onefile=T)

par(mfrow=c(6,3))


for (i in ID$gbgID){
  if (i %in% ID$gbgID[W]) {
    Title<-paste(ID[which(ID$gbgID==i),4],ID[which(ID$gbgID==i),5],
                 ID[which(ID$gbgID==i),6],sep=" ")
    prunedTreeTemp<-prune.sampleFR(names(OTUmr[i,OTUmr[i,]>0]), prunedTree)
    plot(prunedTreeTemp,type="un",show.tip.label = FALSE,use.edge.length=F,
         no.margin = F, )
    
    # Class | Order | Familiy
    fill <- c(plotCol[plotCol$OTUId %in% names(which(OTUmr[i, ] >0)),]$Class)
    pch <- rep(NA,length(fill))
    
    for (k in 1:length(fill)) {
      pch[k] <- PCH[PCH$col == fill[k],]$pch
    }
    
    tiplabels(tip = which(prunedTreeTemp$tip.label %in% names(which(OTUmr[i, ] >0))),
              bg = c25r5[fill],
              pch = pch,
              cex = log(which(OTUmr[i, ] >0),base=10))
    title(main=list(Title,cex=2),col.main=LakeCol[which(Lake == ID[which(ID$gbgID==i),4] )])
    
    # plot ledend
    plot(1, type="n", axes=F, xlab="", ylab="", xlim=c(1,25), ylim=c(1,78),)
    U<-unique(paste(fill,pch,sep="_"))
    
    for (p in 1:length(U)){
      points(x =2 ,y = 76-(p*2),cex =2 ,
             bg = c25r5[as.numeric(sub("(\\d+)_\\d+","\\1",U[p]))],
             pch = as.numeric(sub("\\d+_(\\d+)","\\1",U[p])))
    }
    
    # Class | Order | Familiy
    Tax<-unique(plotTips[plotTips$OTUId %in% names(which(OTUmr[i, ] >0)),]$Class)
    
    for (p in 1:length(U)){
      text(x =3 ,y = 76-(p*2), pos=4, labels=Tax[p], cex=1)
      
    }
    
    title(main=list(Title,cex=2),col.main=LakeCol[which(Lake == ID[which(ID$gbgID==i),4] )])
    
  } else {plot(1, type="n", axes=F, xlab="", ylab="")
          text(x=1,"Sample\n missing \nfrom \nOTUmr5",cex=3)}
}

dev.off()

###################################### heatmap    ##############################


#take average abundance of three dates


IDr <- ID[which(ID$gbgID %in% rownames(OTUmr)),]

OTUav <- matrix(nrow = 0, ncol = ncol(OTUmr))
colnames(OTUav) <- colnames(OTUmr)

row.names <- c()

for (L in levels( as.factor ( IDr$Lake))) {
  for (D in levels( as.factor( IDr$DIL))) {
    
    x <- OTUmr[ rownames(OTUmr) %in% IDr[ IDr$Lake == L & IDr$DIL == D,]$gbgID, ] 
    row.nam <- as.character(IDr[ IDr$Lake == L & IDr$DIL == D,]$gbgID)
    
    if( length( dim(x)) > 0) {
    x <- apply(OTUmr[ rownames(OTUmr) %in% 
                        IDr[ IDr$Lake == L & IDr$DIL == D,]$gbgID, ], 2, mean)
    row.nam <- row.nam[1]
  }
  row.names <- c(row.names, row.nam)
  
 OTUav <-  rbind(OTUav,x)
}}


row.names(OTUav) <- row.names

#split OTU table by ralative abundance in each sample
# abundant : > 1% relative abundance in at least 1 sample
# rare : all that are not abundant

abundantOTU_list <- apply(OTUav,1,function(x) names(which(x > 0.01*sum(x))))
abundantOTU <- unique(unlist(abundantOTU_list))
OTU_ab  <- OTUav[,abundantOTU]

rareOTU_list <- apply(OTUav,1,function(x) names(which(x <= 0.01*sum(x) & x > 0.001*sum(x))))
rareOTU <- unique(unlist(rareOTU_list))
rareOTU <- rareOTU[which(! rareOTU %in% abundantOTU)]
OTU_rar  <- OTUav[,rareOTU]

spouriousOTU_list <- apply(OTUav,1,function(x) names(which(x <= 0.001*sum(x))))
spouriousOTU <- unique(unlist(spouriousOTU_list))
spouriousOTU <- spouriousOTU[-c(which(spouriousOTU %in% rareOTU), which(spouriousOTU %in% abundantOTU))]
OTU_spou <- OTUav[,spouriousOTU]

#taxa table
phy_tax <- as.matrix(OtuTAX[2:8], dimnames = list(OtuTAX$OTUID, colnames(OtuTAX[2:8])))
rownames(phy_tax) <- as.character(OtuTAX$OTUId)

# ID
rownames(ID) <- ID$gbgID

###########  for abundant Taxa ###########

heat_phy_ab <- phyloseq( otu_table( OTU_ab, taxa_are_rows = F), 
                      phy_tree( Tree),
                      sample_data(ID),
                      tax_table(phy_tax))

# sample order
IDphy <- ID[ID$gbgID %in% sample_names(heat_phy_ab),]
sample.order <- as.character(IDphy[with(IDphy, order(Lake,DIL)),]$gbgID)

heat_plot <- plot_heatmap(heat_phy_ab, sample.order = sample.order, sample.label="DIL",
             taxa.label = "Class", first.taxa = "OTU_19",
             title="abundant OTUs (> 1 % of abundance in min 1 sample)")

heat_abund <- heat_plot + 
  facet_grid(~Lake, scales = "free") + 
  theme_bw(base_size = 15)+
  theme(axis.text.y = element_text(hjust = 1, size=8))

heat_abund

ggsave("Figure_2.pdf", heat_abund, width = 10, height = 10)


###########  for rare Taxa ###########

heat_phy_rar <- phyloseq( otu_table( OTU_rar, taxa_are_rows = F), 
                      phy_tree( Tree),
                      sample_data(ID),
                      tax_table(phy_tax))

# sample order
IDphy <- ID[ID$gbgID %in% sample_names(heat_phy_rar),]
sample.order <- as.character(IDphy[with(IDphy, order(Lake,DAT,DIL)),]$gbgID)

heat_plot <- plot_heatmap(heat_phy_rar, sample.order = sample.order, sample.label="Lake",
             taxa.label = "Family", 
             title="rare OTUs (< 1 % )")

heat_plot + 
  facet_grid(~Lake, scales = "free") + 
  theme_bw(base_size = 15)+
  theme(axis.text.y = element_text(hjust = 1, size=8))



###########  for spourious Taxa ###########

heat_phy_spou <- phyloseq( otu_table( OTU_spou, taxa_are_rows = F), 
                      phy_tree( Tree),
                      sample_data(ID),
                      tax_table(phy_tax))

# sample order
IDphy <- ID[ID$gbgID %in% sample_names(heat_phy_spou),]
sample.order <- as.character(IDphy[with(IDphy, order(Lake,DAT,DIL)),]$gbgID)

heat_plot <- plot_heatmap(heat_phy_spou, sample.order = sample.order, sample.label="Lake",
             taxa.label = "Family", title="Spourious OTUs (< 0.1 % of abundance)")

heat_plot + 
  facet_grid(~Lake, scales = "free") + 
  theme_bw(base_size = 15)+
  theme(axis.text.y = element_text(hjust = 1, size=8))



