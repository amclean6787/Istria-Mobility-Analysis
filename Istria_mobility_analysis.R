# McLean and Sprem 2024
# Mobility Analyses

# Setup ###
# Mount packages
library(tidyverse)
library(terra)
library(leastcostpath)
library(sf)

# Setup ####

# Cost Surface #

DEM <- rast("Data/Input/Cost_surfaces/ISTR_DEM_10m.tif") # Import DEM (A clipped raster from Copernicus https://spacedata.copernicus.eu/collections/copernicus-digital-elevation-model)

Nodes <- st_read("Data/Input/Shapefiles/LCP_nodes/LCP_nodes.shp") # Import nodes fro LCP analysis. We will use this to reproject the cost surface to the appropriate CRS in the setup

DEM <- terra::aggregate(DEM, fact = 3, fun = mean, na.rm = T) # Transform from 10m resolution to 30m

Slope <- terra::terrain(DEM, "slope", neighbors = 8, unit = "degrees") # DEM to Slope

Speed <- (-0.033*Slope) + 1.357 # Slope to walking speed (Equation from Bosina and Weidmann (2017))
Speed[Speed < 0.1] <- 0.1 # Remove low and negative speed values

Time <- (res(Speed)[1]*111000)/Speed # Speed to Time (Raster resolution is in degrees and has to be converted to metres, so roughly 111,000 difference at the given latitude)

Time_reprojected <- terra::project(Time, sf::st_crs(Nodes)$wkt) # Reproject Time raster to have the same CRS as the rest of the spatial objects used
  
writeRaster(Time_reprojected, "Data/Input/Cost_surfaces/ISTR_Time_30m.tif") # Export Time raster

rm(list = ls())
gc() # Free up memory

# LCP Analysis ####
Nodes <- st_read("Data/Input/Shapefiles/LCP_nodes/LCP_nodes.shp") # Import Nodes for LCP analysis
Time <- rast("Data/Input/Cost_surfaces/ISTR_Time_30m.tif") # Import Time raster

Time_inv <- 1/Time # Invert cost raster to conductance

Time_matrix <- create_cs(Time_inv, neighbours = 8) # Create conductance matrix

rm(Time, Time_inv)
gc() # Free up memory

# Run LCP analysis
Points <- c(1,3, 3,4, 4,6, 2,5, 5,6, 6,13, 6,7, 13,7, 7,8, 8,9, 9,10, 10,11, 11,12) # This sets up the specified routes, each pair is a route between two nodes

for (LCP in seq(from = 1, to = length(Points), by = 2)) { # This for loop runs every LCP route and merges them into a single shapefile for export
  
  LCP_tmp <- leastcostpath::create_lcp(x = Time_matrix, origin = st_coordinates(Nodes[Nodes$id == Points[LCP],]), destination = st_coordinates(Nodes[Nodes$id == Points[(LCP+1)],]), cost_distance = T) # Run LCP analysis for specific LCP in route
  
  if (!exists("LCP_full")){
    
    LCP_count <- 1
    
    LCP_full <- LCP_tmp
    print(paste0("LCP ", LCP_count, " of ", (length(Points)/2), " complete."))
    
    # Create merged LCPs if it does not already exist
    
  }
  
  else {
    
    LCP_count <- LCP_count + 1
    
    LCP_full <- rbind(LCP_full, LCP_tmp)
    print(paste0("LCP ", LCP_count, " of ", (length(Points)/2), " complete."))
    
    # Add current LCP to merged LCPs
    
  }
  
  rm(LCP_tmp)
  
}

# Tidy LCPs
Route_pairs <- str_c(Points[c(TRUE, FALSE)], Points[c(FALSE, TRUE)], sep=" and ")

Toponym_map <- Nodes$Toponymn
names(Toponym_map) <- Nodes$id
Route_pairs_named <- str_replace_all(Route_pairs, "\\d+", function(x) Toponym_map[x])
LCP_full$Route <- Route_pairs_named

LCP_full$cost_mins <- LCP_full$cost/60
LCP_full$cost_hrs <- LCP_full$cost_mins/60

LCP_full <- LCP_full[,c(6,4,7,8)]

names(LCP_full)[2] <- "cost_secs"

st_write(LCP_full, "Data/Output/LCP/Shapefiles/LCP_node_routes/LCP_node_routes.shp") # Export merged LCP

LCP_data <- LCP_full
LCP_data$geometry <- NULL
write_csv(LCP_data,"Data/Output/LCP/LCP_costs.csv")  

rm(list = ls())
gc() # Free up memory

# Cost Corridor Analysis ####
# This in mainly conducted in GRASS GIS, but the set up is performed in R and only requires the generated scripts to be run in GRASS GIS

# Import data
Nodes <- st_read("Data/Input/Shapefiles/LCP_nodes/LCP_nodes.shp") # Import Nodes
Nodes$Toponymn <- gsub("[ ,*().]", "_", Nodes$Toponymn) # Ensure node names are readable in GRASS

File_path <- "Data/Input/GRASS/GRASS_cost_ISTR_nodes.sh" # Set script file path

if(file.exists(File_path)){
  
  file.remove(File_path)
  
} # Remove old version of script file if it exists

for (Node in Nodes$Toponymn) { # Generate the GRASS script to create a cumulative cost surface for every node
  
  Text_to_add <- paste0("r.cost -k --overwrite input=ISTR_Time_30m@PERMANENT output=ISTR_CmCost_", Node, "_30m@PERMANENT start_coordinates=", st_coordinates(Nodes[Nodes$Toponymn == Node,])[1], ",",st_coordinates(Nodes[Nodes$Toponymn == Node,])[2]) # Iteratively create the appropriate line of code for each node
  
  File_connection <- file(File_path, open = "a")
  writeLines(Text_to_add, File_connection)
  close(File_connection) # Add each line to the script file
  
  if(Node == Nodes$Toponymn[nrow(Nodes)]){
    
    Text_to_add <- paste0("echo \"Finished processing\"")
    
    File_connection <- file(File_path, open = "a")
    writeLines(Text_to_add, File_connection)
    close(File_connection)
    
  }
  
}

# Create script to export cumulative cost surfaces from GRASS

if(file.exists("Data/Input/GRASS/GRASS_export_ISTR_nodes.sh")){
  
  file.remove("Data/Input/GRASS/GRASS_export_ISTR_nodes.sh")
  
} # Create the script file and delete old version if it exists

File_path <- getwd()
File_path <- gsub("/", "\\\\", File_path) 


for (Node in Nodes$Toponymn) {
  
  cat("\nr.out.gdal input=ISTR_CmCost_", Node, "_30m@PERMANENT output=\"", File_path, "\\Data\\Output\\Cost_corridors\\Cumulative_cost_rasters\\ISTR_CmCost_", Node, "_30m\"  format=GTiff", sep = "", file = "Data/Input/GRASS/GRASS_export_ISTR_nodes.sh", append = T)
  
}

# Run the GRASS Scripts in GRASS and then create the cost corridors from the cumulative cost surfaces with the code below.

Points <- c(1,3, 3,4, 4,6, 2,5, 5,6, 6,13, 6,7, 13,7, 7,8, 8,9, 9,10, 10,11, 11,12) # This sets up the specified routes, each pair is a route between two nodes

for (Corridor in seq(from = 1, to = length(Points), by = 2)){ # This loop averages the cumulative cost surface between the pairs of nodes outlined in Points to create the cost corridors

  Origin <- Nodes$Toponymn[Nodes$id == Points[Corridor]]
  Destination <- Nodes$Toponymn[Nodes$id == Points[Corridor + 1]]
  
  Current_orig <- rast(paste0("Data/Output/Cost_corridors/Cumulative_cost_rasters/ISTR_CmCost_", Origin, "_30m"))

  Current_dest <- rast(paste0("Data/Output/Cost_corridors/Cumulative_cost_rasters/ISTR_CmCost_", Destination, "_30m"))

  Cost_corridor <- terra::app(c(Current_orig, Current_dest), fun = mean)

  writeRaster(Cost_corridor, paste0("Data/Output/Cost_corridors/Corridors/ISTR_Cst_coridor_", Origin, "-", Destination, "_30m.tif"))

  rm(Current_orig, Current_dest, Cost_corridor)
  gc()

  if (!exists("Iteration")){
  
    Iteration <- 1
  
  }
  
  else (Iteration <- Iteration + 1)
  
  print(paste0("Cost corridor between ", Origin, " and ", Destination, " complete (Corridor ", Iteration, " of ", length(Points)/2, ")."))
  
  if (Iteration == length(Points)/2){
    
    rm(Iteration)
    
  }
  
}

rm(list = ls())
gc() # Free up memory

# Circuit Theory Analysis ####
# Convert Rasters to ASCII
Time <- rast("Data/Input/Cost_surfaces/ISTR_Time_30m.tif")
writeRaster(Time, "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_30m.asc")

Nodes_rast <- rast("Data/Input/CT/Sources/TIF/Nodes.tif")
writeRaster(Nodes_rast, "Data/Input/CT/Sources/ASCII/Nodes.asc")

# Create individual Node rasters for outputs between pairs
Nodes <- st_read("Data/Input/Shapefiles/LCP_nodes/LCP_nodes.shp") # Import Nodes
for (Node in 1:nrow(Nodes)) {
  
  Tmp_nodes_rast <- ifel(Nodes_rast == Node, Node, NA)
  writeRaster(Tmp_nodes_rast, paste0("Data/Input/CT/Sources/TIF/Individual_nodes/Node_", Node, ".tif"))
  writeRaster(Tmp_nodes_rast, paste0("Data/Input/CT/Sources/ASCII/Individual_nodes/Node_", Node, ".asc"))
  
}

# Create Sea Cost Rasters for advanced analysis ###
# This creates rasters from the Time raster where NA values are set to the max, average or minimum cost of the Time raster

# High Cost Sea
Time_hicst_sea <- Time
Time_hicst_sea[is.na(Time_hicst_sea)] <- minmax(Time_hicst_sea)[2]
writeRaster(Time_hicst_sea, "Data/Input/CT/Cost_surfaces/TIF/ISTR_Time_seahi_30m.tif")
writeRaster(Time_hicst_sea, "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_seahi_30m.asc")

# Low Cost Sea
Time_locst_sea <- Time
Time_locst_sea[is.na(Time_locst_sea)] <- minmax(Time_locst_sea)[1]
writeRaster(Time_locst_sea, "Data/Input/CT/Cost_surfaces/TIF/ISTR_Time_sealo_30m.tif")
writeRaster(Time_locst_sea, "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_sealo_30m.asc")

# Average Cost Sea
Time_avcst_sea <- Time
Time_avcst_sea[is.na(Time_avcst_sea)] <- global(Time_avcst_sea, fun = mean, na.rm = T)
writeRaster(Time_avcst_sea, "Data/Input/CT/Cost_surfaces/TIF/ISTR_Time_seaav_30m.tif")
writeRaster(Time_avcst_sea, "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_seaav_30m.asc")

# Add Borders ###
# Borders are necessary for the advanced circuitscape analysis
North <- Time_hicst_sea
values(North) <- NA  # Set all values to NA
North[1, ] <- 1  # Set north border values to 1
writeRaster(North, "Data/Input/CT/Sources/TIF/ISTR_north_30m.tif")
writeRaster(North, "Data/Input/CT/Sources/ASCII/ISTR_north_30m.asc")


South <- Time_hicst_sea
values(South) <- NA  # Set all values to NA
South[nrow(South), ] <- 1  # Set north border values to 1
writeRaster(South, "Data/Input/CT/Sources/TIF/ISTR_south_30m.tif")
writeRaster(South, "Data/Input/CT/Sources/ASCII/ISTR_south_30m.asc")

East <- Time_hicst_sea
values(East) <- NA  # Set all values to NA
East[, ncol(East)] <- 1  # Set north border values to 1
writeRaster(East, "Data/Input/CT/Sources/TIF/ISTR_east_30m.tif")
writeRaster(East, "Data/Input/CT/Sources/ASCII/ISTR_east_30m.asc")

West <- Time_hicst_sea
values(West) <- NA  # Set all values to NA
West[, 1] <- 1  # Set north border values to 1
writeRaster(West, "Data/Input/CT/Sources/TIF/ISTR_west_30m.tif")
writeRaster(West, "Data/Input/CT/Sources/ASCII/ISTR_west_30m.asc")

# Create CT config files
# Create a function for generating CT config files
Create_ini_file <- function(Tmp_path, New_path, Pointfile = "<POINTFILE>", Outputfile, Habitatfile, Sourcefile = "<SOURCEFILE>", Groundfile = "<GROUNDFILE>") {
  # Read the template file
  Template_content <- readLines(Tmp_path)
  
  # Replace placeholders
  Template_content <- gsub("<POINTFILE>", Pointfile, Template_content)
  Template_content <- gsub("<OUTPUTFILE>", Outputfile, Template_content)
  Template_content <- gsub("<HABITATFILE>", Habitatfile, Template_content)
  Template_content <- gsub("<SOURCEFILE>", Sourcefile, Template_content)
  Template_content <- gsub("<GROUNDFILE>", Groundfile, Template_content)
  
  # Write the modified content to a new .ini file
  writeLines(Template_content, New_path)
}

Create_ini_file(Tmp_path= "Data/Input/CT/Config/INI/Templates/Pairwise_TEMPL.ini", New_path = "Data/Input/CT/Config/INI/Nodes_pairwiseTEST.ini", Pointfile= "Data/Input/CT/Sources/ASCII/Nodes.asc", Outputfile = "Data/Output/CT/Nodes_pairwise/Nodes_all_pairwise.out", Habitatfile = "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_30m.asc") # Create simple pairwise config file

# Create advanced Node config files
Points <- c(1,3, 3,4, 4,6, 2,5, 5,6, 6,13, 6,7, 13,7, 7,8, 8,9, 9,10, 10,11, 11,12) # This sets up the specified routes, each pair is a route between two nodes

for (Node_pair in seq(from = 1, to = length(Points), by = 2)){
  
  Create_ini_file(Tmp_path= "Data/Input/CT/Config/INI/Templates/Advanced_TEMPL.ini", New_path = paste0("Data/Input/CT/Config/INI/Advanced_nodes/Node_", Points[Node_pair], "_to_Node_", Points[Node_pair + 1], ".ini"), Outputfile = paste0("Data/Output/CT/Nodes_pairwise/Advanced/Node_",Points[Node_pair], "_to_Node_", Points[Node_pair + 1], ".out"), Habitatfile = "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_30m.asc", Sourcefile = paste0("Data/Input/CT/Sources/ASCII/Individual_nodes/Node_", Points[Node_pair], ".asc"), Groundfile = paste0("Data/Input/CT/Sources/ASCII/Individual_nodes/Node_", Points[Node_pair] + 1, ".asc")) # Create advanced  Node config file
  
}

# Create advanced directional config files
for (Direction in c("north_south", "south_north", "east_west", "west_east")){
  
  Parts <- strsplit(Direction, "[_]")
  
  Create_ini_file(Tmp_path= "Data/Input/CT/Config/INI/Templates/Advanced_TEMPL.ini", New_path = paste0("Data/Input/CT/Config/INI/Directional/", Parts[[1]][1], "-", Parts[[1]][2], "_seaav.ini"), Outputfile = paste0("Data/Output/CT/Directional/", Parts[[1]][1], "-", Parts[[1]][2], "_seaav.out"), Habitatfile = "Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_seaav_30m.asc", Sourcefile = paste0("Data/Input/CT/Sources/ASCII/ISTR_",Parts[[1]][1], "_30m.asc"), Groundfile = paste0("Data/Input/CT/Sources/ASCII/ISTR_",Parts[[1]][2], "_30m.asc")) # Create advanced directional config files
  
}

# Now the CT analysis can be run in Julia using the config files generated and the Julia script provided, before running the final R code below to tidy the CT outputs

# Set sea values to NULL and convert ASCII CT outputs to .tif
Time <- rast("Data/Input/CT/Cost_surfaces/ASCII/ISTR_Time_30m.asc")

ISTR_NS <- rast("Data/Output/CT/Directional/north-south_seaav_curmap.asc")
ISTR_NS <- ifel(is.na(Time), NA, ISTR_NS)
writeRaster(ISTR_NS, "Data/Output/CT/Directional/TIF/north-south_seaav_curmap.tif")

ISTR_SN <- rast("Data/Output/CT/Directional/south-north_seaav_curmap.asc")
ISTR_SN <- ifel(is.na(Time), NA, ISTR_SN)
writeRaster(ISTR_SN, "Data/Output/CT/Directional/TIF/south-north_seaav_curmap.tif")

ISTR_EW <- rast("Data/Output/CT/Directional/east-west_seaav_curmap.asc")
ISTR_EW <- ifel(is.na(Time), NA, ISTR_EW)
writeRaster(ISTR_EW, "Data/Output/CT/Directional/TIF/east-west_seaav_curmap.tif")

ISTR_WE <- rast("Data/Output/CT/Directional/west-east_seaav_curmap.asc")
ISTR_WE <- ifel(is.na(Time), NA, ISTR_WE)
writeRaster(ISTR_WE, "Data/Output/CT/Directional/TIF/west-east_seaav_curmap.tif")

# Create Average of Directional CT Outputs
ISTR_CT_avg <- terra::app(c(ISTR_NS, ISTR_SN, ISTR_EW, ISTR_WE), fun = mean)
writeRaster(ISTR_CT_avg, "Data/Output/CT/Directional/TIF/Average_seaav_curmap.tif")

rm(list = ls())
gc() # Free up memory

# Statistical Analysis ####
Rural_no_island <- st_read("Data/Input/Shapefiles/Rural_sites_no_island_buffer_1km/Rural_sites_no_island_buffer_1km.shp") # Import rural sites

Cities <- st_read("Data/Input/Shapefiles/Roman_cities/Roman_cities_1km_buffer/Roman_cities_1km_buffer.shp") # Import urban sites

# Mean values ###
# Average
ISTR_CT <- rast("Data/Output/CT/Directional/TIF/Average_seaav_curmap.tif")

mean_values <- extract(ISTR_CT, Rural_no_island, fun = mean, na.rm = T)
Rural_no_island$Mean_CT_avg <- mean_values[,2]

mean_values <- extract(ISTR_CT, Cities, fun = mean, na.rm = T)
Cities$Mean_CT_avg <- mean_values[,2]

rm(ISTR_CT)

# North to South
ISTR_NS_CT <- rast("Data/Output/CT/Directional/TIF/north-south_seaav_curmap.tif")

mean_values <- extract(ISTR_NS_CT, Rural_no_island, fun = mean, na.rm = T)
Rural_no_island$Mean_CT_S <- mean_values[,2]

mean_values <- extract(ISTR_NS_CT, Cities, fun = mean, na.rm = T)
Cities$Mean_CT_S <- mean_values[,2]

rm(ISTR_NS_CT)

# South to North
ISTR_SN_CT <- rast("Data/Output/CT/Directional/TIF/south-north_seaav_curmap.tif")

mean_values <- extract(ISTR_SN_CT, Rural_no_island, fun = mean, na.rm = T)
Rural_no_island$Mean_CT_N <- mean_values[,2]

mean_values <- extract(ISTR_SN_CT, Cities, fun = mean, na.rm = T)
Cities$Mean_CT_N <- mean_values[,2]

rm(ISTR_SN_CT)

# West to East
ISTR_WE_CT <- rast("Data/Output/CT/Directional/TIF/west-east_seaav_curmap.tif")

mean_values <- extract(ISTR_WE_CT, Rural_no_island, fun = mean, na.rm = T)
Rural_no_island$Mean_CT_E <- mean_values[,2]

mean_values <- extract(ISTR_WE_CT, Cities, fun = mean, na.rm = T)
Cities$Mean_CT_E <- mean_values[,2]

rm(ISTR_WE_CT)

# East to West
ISTR_EW_CT <- rast("Data/Output/CT/Directional/TIF/east-west_seaav_curmap.tif")

mean_values <- extract(ISTR_EW_CT, Rural_no_island, fun = mean, na.rm = T)
Rural_no_island$Mean_CT_W <- mean_values[,2]

mean_values <- extract(ISTR_EW_CT, Cities, fun = mean, na.rm = T)
Cities$Mean_CT_W <- mean_values[,2]

rm(ISTR_EW_CT, mean_values)

# Max values ###
# Average
ISTR_CT <- rast("Data/Output/CT/Directional/TIF/Average_seaav_curmap.tif")

max_values <- extract(ISTR_CT, Rural_no_island, fun = max, na.rm = T)
Rural_no_island$Max_CT_avg <- max_values[,2]

max_values <- extract(ISTR_CT, Cities, fun = max, na.rm = T)
Cities$Max_CT_avg <- max_values[,2]

rm(ISTR_CT)

# North to South
ISTR_NS_CT <- rast("Data/Output/CT/Directional/TIF/north-south_seaav_curmap.tif")

max_values <- extract(ISTR_NS_CT, Rural_no_island, fun = max, na.rm = T)
Rural_no_island$Max_CT_S <- max_values[,2]

max_values <- extract(ISTR_NS_CT, Cities, fun = max, na.rm = T)
Cities$Max_CT_S <- max_values[,2]

rm(ISTR_NS_CT)

# South to North
ISTR_SN_CT <- rast("Data/Output/CT/Directional/TIF/south-north_seaav_curmap.tif")

max_values <- extract(ISTR_SN_CT, Rural_no_island, fun = max, na.rm = T)
Rural_no_island$Max_CT_N <- max_values[,2]

max_values <- extract(ISTR_SN_CT, Cities, fun = max, na.rm = T)
Cities$Max_CT_N <- max_values[,2]

rm(ISTR_SN_CT)

# West to East
ISTR_WE_CT <- rast("Data/Output/CT/Directional/TIF/west-east_seaav_curmap.tif")

max_values <- extract(ISTR_WE_CT, Rural_no_island, fun = max, na.rm = T)
Rural_no_island$Max_CT_E <- max_values[,2]

max_values <- extract(ISTR_WE_CT, Cities, fun = max, na.rm = T)
Cities$Max_CT_E <- max_values[,2]

rm(ISTR_WE_CT)

# East to West
ISTR_EW_CT <- rast("Data/Output/CT/Directional/TIF/east-west_seaav_curmap.tif")

max_values <- extract(ISTR_EW_CT, Rural_no_island, fun = max, na.rm = T)
Rural_no_island$Max_CT_W <- max_values[,2]

max_values <- extract(ISTR_EW_CT, Cities, fun = max, na.rm = T)
Cities$Max_CT_W <- max_values[,2]

rm(ISTR_EW_CT)

# Export Data
# Rural
Rural_no_island <- vect(Rural_no_island)
Rural_no_island_points <- centroids(Rural_no_island) # Transform polygon/buffer shapefile to point shapefile

writeVector(Rural_no_island_points, "Data/Output/CT/Rural_sites/Rural_sites_no_island_mean_max_points/Rural_sites_no_island_mean_max_points.shp")

Rural_no_island_points <-  st_read("Data/Output/CT/Rural_sites/Rural_sites_no_island_mean_max_points/Rural_sites_no_island_mean_max_points.shp")

write_csv(Rural_no_island_points, "Data/Output/CT/Rural_sites/Rural_sites_no_island_mean_max.csv")

# Urban

Cities <- vect(Cities)
Cities_points <- centroids(Cities) # Transform polygon/buffer shapefile to point shapefile

writeVector(Cities_points, "Data/Output/CT/Urban/Urban_mean_max_points.shp")

Cities_points <- st_read("Data/Output/CT/Urban/Urban_mean_max_points.shp")

write_csv(Cities_points, "Data/Output/CT/Urban/Urban_mean_max.csv")

rm(list = ls())
gc() # Free up memory


# LCP
Rural_LCPs <- read_csv("Data/Output/LCP/Rural_urban_full_costs.csv")

ggplot(Rural_LCPs, aes(`Time (Hours)`)) + geom_density(colour ="indianred3", lwd =1.5) + labs(title = "Cost from Rural Sites to Nearest Urban Centre", y = "Density") + theme_bw() 

ggplot(Rural_LCPs, aes(`Time (Hours)`)) + geom_histogram(fill ="indianred3", colour = "black") + labs(title = "Cost from Rural Sites to Nearest Urban Centre", y = "Number of Sites") + theme_bw()


# Check Mean Values ##
Urban_CT <- read_csv("Data/Output/CT/Urban/Urban_mean_max.csv")
Rural_CT <- read_csv("Data/Output/CT/Rural_sites/Rural_sites_no_island_mean_max.csv")

ggplot(Rural_CT, aes(Mean_CT_av)) + geom_histogram(fill ="indianred3", colour = "black") + labs(title = "Mean CT Value of Rural Sites", y = "Number of Sites", x = "Mean CT Value") + theme_bw()


# Mean
mean(Urban_CT$Mean_CT_av)
mean(Rural_CT$Mean_CT_av)

shapiro.test(Urban_CT$Mean_CT_av)
shapiro.test(Rural_CT$Mean_CT_av)

ks.test(Urban_CT$Mean_CT_av, Rural_CT$Mean_CT_av)

# Max
mean(Urban_CT$Max_CT_avg)
mean(Rural_CT$Max_CT_avg)

shapiro.test(Urban_CT$Max_CT_avg)
shapiro.test(Rural_CT$Max_CT_avg)

ks.test(Urban_CT$Max_CT_avg, Rural_CT$Max_CT_avg)

# END #
