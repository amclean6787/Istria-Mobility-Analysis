# Istria-Mobility-Analysis

## Table of Contents
* [General Info](#general-info)
* [Requirements](#requirements)
* [Process](#process)
* [Data Structure](#data-structure)
* [Authors and Contact](#author-and-contact)

## General Info
This repository contains the source code for the paper submitted to XXXX.

## Requirements
Most of the setup and analysis was conducted in R, with some of the Cost Corridor analysis using GRASS GIS and the LCPs in QGIS and the actual implementation of circuit theory using the circuitscape package in Julia.
R, GRASS GIS, Julia and QQGIS are all open source and are all that are required to reproduce this analysis. The requried R packages are- 

* tidyverse
* terra
* leastcostpath
* sf

## Process
* Download the datasets from : XXXX
* Ensure inputs and source code are within the same root folder
* Run the setup R script (Istria_mobility_analysis.R) (lines 1-45) and then the LCP analysis (lines 46-102)
* Run the GRASS setup R script (lines 103-155) and then generate the cost corridors in GRASS GIS using r.cost and return to finish the analysis in R (lines 157-196)
* Run the CT setup R script (lines 197-299) and then run the Julia script to generate the CT outputs before returning to R to tidy the CT outputs (lines 301-327)
* Run the statistical analysis in R (lines 328-500)
* Outputs are stored in the respecitve output folders (the original results are included)

## Data Structure

## Authors and Contact
Andrew McLean-


   Barcelona Supercomputing Center (BSC)
   
   andrew.mclean@bsc.es
   

Katarina Šprem
