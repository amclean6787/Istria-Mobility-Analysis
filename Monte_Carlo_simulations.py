import random
from qgis.core import QgsGeometry, QgsPointXY, QgsFeature, QgsVectorLayer, QgsProject
from qgis.analysis import QgsZonalStatistics

# Parameters
num_simulations = 100  # Number of Monte Carlo iterations
num_points = 300       # Points per simulation
buffer_distance = 0.009 # 1km buffer (in CRS units)
raster_layer_name = "Raster_layer" 

# Get raster layer
raster_layer = QgsProject.instance().mapLayersByName(raster_layer_name)[0]
extent = raster_layer.extent()

# Store results
all_simulation_means = []  # Mean values per simulation
all_simulation_maxs = []   # Max values per simulation
site_means = []            # Mean values per site (across all sims)
site_maxs = []             # Max values per site (across all sims)

for sim in range(num_simulations):
    # Create random points
    points_layer = QgsVectorLayer("Point?crs=" + raster_layer.crs().authid(), f"points_sim_{sim}", "memory")
    provider = points_layer.dataProvider()
    
    for _ in range(num_points):
        x = random.uniform(extent.xMinimum(), extent.xMaximum())
        y = random.uniform(extent.yMinimum(), extent.yMaximum())
        point = QgsGeometry.fromPointXY(QgsPointXY(x, y))
        feature = QgsFeature()
        feature.setGeometry(point)
        provider.addFeature(feature)
    
    # Buffer points
    buffered_layer = processing.run("native:buffer", {
        'INPUT': points_layer,
        'DISTANCE': buffer_distance,
        'OUTPUT': 'memory:'
    })['OUTPUT']
    
    # Calculate zonal stats (MEAN and MAX)
    zonal_stats_mean = QgsZonalStatistics(buffered_layer, raster_layer, "mean_", 1, QgsZonalStatistics.Mean)
    zonal_stats_max = QgsZonalStatistics(buffered_layer, raster_layer, "max_", 1, QgsZonalStatistics.Max)
    zonal_stats_mean.calculateStatistics(None)
    zonal_stats_max.calculateStatistics(None)
    
    # Extract non-NULL values
    sim_means = []
    sim_maxs = []
    for feature in buffered_layer.getFeatures():
        mean_val = feature["mean_mean"]
        max_val = feature["max_max"]
        if mean_val is not None:
            sim_means.append(mean_val)
            site_means.append(mean_val)  # Track per-site mean across sims
        if max_val is not None:
            sim_maxs.append(max_val)
            site_maxs.append(max_val)     # Track per-site max across sims
    
    # Store simulation averages
    if sim_means:
        all_simulation_means.append(sum(sim_means) / len(sim_means))
    if sim_maxs:
        all_simulation_maxs.append(sum(sim_maxs) / len(sim_maxs))
    
    # Clean up
    QgsProject.instance().removeMapLayer(points_layer)
    QgsProject.instance().removeMapLayer(buffered_layer)

# Calculate global statistics
def safe_average(values):
    return sum(values) / len(values) if values else None

global_mean_avg = safe_average(all_simulation_means)  # Avg of simulation averages
global_max_avg = safe_average(all_simulation_maxs)    # Avg of simulation maxes
site_mean_avg = safe_average(site_means)              # Avg of ALL site means
site_max_avg = safe_average(site_maxs)                # Avg of ALL site maxes

# Print results
print("=== Results ===")
print(f"Global average MEAN across {len(all_simulation_means)} simulations: {global_mean_avg}")
print(f"Global average MAX across {len(all_simulation_maxs)} simulations: {global_max_avg}")
print(f"Average MEAN per site (all sims combined): {site_mean_avg}")
print(f"Average MAX per site (all sims combined): {site_max_avg}")