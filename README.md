# Istria-Mobility-Analysis

## Table of Contents
* [General Info](#general-info)
* [Requirements](#requirements)
* [Process](#process)
* [Data Structure](#data-structure)
* [Authors and Contact](#author-and-contact)

## General Info
This repository contains the source code for the paper submitted to the Journal of Archaeological Method and Theory. The data inputs can be found at: https://figshare.com/s/ff2b987801ba8bb0ef4f and outputs at: https://figshare.com/s/1b862ee146e80fb07de2

## Requirements
Most of the setup and analysis was conducted in R, with some of the Cost Corridor analysis using GRASS GIS and the LCPs in QGIS and the actual implementation of circuit theory using the circuitscape package in Julia.
R, GRASS GIS, Julia and QQGIS are all open source and are all that are required to reproduce this analysis. The requried R packages are- 

* tidyverse
* terra
* leastcostpath
* sf

## Process
* Download the datasets
* Ensure inputs and source code are within the same root folder
* Run the setup R script (Istria_mobility_analysis.R) (lines 1-45) and then the LCP analysis (lines 46-102)
* Run the GRASS setup R script (lines 103-155) and then generate the cost corridors in GRASS GIS using r.cost and return to finish the analysis in R (lines 157-196)
* Run the CT setup R script (lines 197-299) and then run the Julia script to generate the CT outputs before returning to R to tidy the CT outputs (lines 301-327)
* Run the statistical analysis in R (lines 328-504)
* Outputs are stored in the respecitve output folders (the original results are included)

## Data Structure
Input -> Cost_surfaces (Cost surface DEM and Time)
Input -> CT (Inputs for CT analysis, ASCII cost surfaces and sources as well as configuration .ini files)
Input -> GRASS (Scripts for running and exporting the GRASS GIS analyses)
Input -> Shapefiles (The point shapefiles used in the analyses)

Output-> Cost_corridors (Cost corridor outputs including cumulative cost surfaces)
Output-> CT (Outputs for CT analysis, including directional TIF outputs and ASCII outputs for Advanced method. The analyses of the Rural and Urban sites with these data is included here)
Output-> LCP (Least Cost Path analyses outputs, including LCPs themselves and breakdown of costs)
Output-> Road_network (The final output of the reconstructed Istrian road network as well as digitised versions of the original qualitative reconstructions)

## Authors and Contact
Andrew McLean-


   Barcelona Supercomputing Center (BSC)
   
   andrew.mclean@bsc.es
   

Katarina Šprem
