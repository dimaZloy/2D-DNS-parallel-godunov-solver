

@everywhere mutable struct viscousFields2d

	viscosityCells::Array{Float64,1}
	viscosityNodes::Array{Float64,1}
	
	#dUdxCells::Array{Float64,1}
	#dUdyCells::Array{Float64,1}
	
	#dVdxCells::Array{Float64,1}
	#dVdyCells::Array{Float64,1}
	
	laplasUCuCells::Array{Float64,1}
	laplasUCvCells::Array{Float64,1}
	laplasUCeCells::Array{Float64,1}
	
	cdUdxCells::Array{Float64,1}
	cdUdyCells::Array{Float64,1}
	cdVdxCells::Array{Float64,1}
	cdVdyCells::Array{Float64,1}
	cdEdxCells::Array{Float64,1}
	cdEdyCells::Array{Float64,1}

	cdUdxNodes::Array{Float64,1}
	cdUdyNodes::Array{Float64,1}
	cdVdxNodes::Array{Float64,1}
	cdVdyNodes::Array{Float64,1}
	cdEdxNodes::Array{Float64,1}
	cdEdyNodes::Array{Float64,1}


end

# @everywhere mutable struct viscousFields2d_shared
	
	# artViscosityCells::SharedArray{Float64,1}
	# artViscosityNodes::SharedArray{Float64,1}
	
	# dUdxCells::SharedArray{Float64,1}
	# dUdyCells::SharedArray{Float64,1}
	
	# dVdxCells::SharedArray{Float64,1}
	# dVdyCells::SharedArray{Float64,1}
	
	# laplasUCuCells::SharedArray{Float64,1}
	# laplasUCvCells::SharedArray{Float64,1}
	# laplasUCeCells::SharedArray{Float64,1}
	
	# cdUdxCells::SharedArray{Float64,1}
	# cdUdyCells::SharedArray{Float64,1}
	
	# cdVdxCells::SharedArray{Float64,1}
	# cdVdyCells::SharedArray{Float64,1}
	# cdEdxCells::SharedArray{Float64,1}
	# cdEdyCells::SharedArray{Float64,1}

# end


# @everywhere mutable struct fields2d_shared
	
	# ## even more slowly !!!
	# ##UphsCells::Array{Float64,2} 
	# ##UphsNodes::Array{Float64,2}
	
	# densityCells::SharedArray{Float64,1}
	# UxCells::SharedArray{Float64,1}
	# UyCells::SharedArray{Float64,1}
	# pressureCells::SharedArray{Float64,1}
	# aSoundCells::SharedArray{Float64,1}
	# VMAXCells::SharedArray{Float64,1}

	# densityNodes::SharedArray{Float64,1}
	# UxNodes::SharedArray{Float64,1}
	# UyNodes::SharedArray{Float64,1}
	# pressureNodes::SharedArray{Float64,1}
	

	# #UconsCellsOld::Array{Float64,2}
	# #UconsCellsNew::Array{Float64,2}

# end

@everywhere mutable struct fields2d	
	
	## even more slowly !!!
	##UphsCells::Array{Float64,2} 
	##UphsNodes::Array{Float64,2}
	
	densityCells::Array{Float64,1}
	UxCells::Array{Float64,1}
	UyCells::Array{Float64,1}
	pressureCells::Array{Float64,1}
	aSoundCells::Array{Float64,1}
	VMAXCells::Array{Float64,1}

	densityNodes::Array{Float64,1}
	UxNodes::Array{Float64,1}
	UyNodes::Array{Float64,1}
	pressureNodes::Array{Float64,1}
	
	#UconsCellsOld::Array{Float64,2}
	#UconsCellsNew::Array{Float64,2}

end


@everywhere struct mesh2d_Int32
	nCells::Int64
	nNodes::Int64
	nNeibCells::Int32						## max number of neighbors 
	nBSets::Int32							##  number of boundaries  
	xNodes::Array{Float64,1} 				##  mesh_nodes[nNodesx3]
	yNodes::Array{Float64,1} 				##	mesh_nodes[nNodesx3]
	mesh_connectivity::Array{Int32,2} 		## [nCellsx7]
	bc_data::Array{Int32,2}
	bc_indexes::Array{Int32,1}
	cell_nodes_X::Array{Float64,2} 			## [nCellsx4]
	cell_nodes_Y::Array{Float64,2} 			## [nCellsx4]
	cell_mid_points::Array{Float64,2} 		## [nCellsx2]
	cell_areas::Array{Float64,1} 			## [nCellsx1]
	HX::Array{Float64,1}
	cell_edges_Nx::Array{Float64,2} 		## [nCellsx4]
	cell_edges_Ny::Array{Float64,2} 		## [nCellsx4]
	cell_edges_length::Array{Float64,2} 	## [nCellsx4]
	cell_stiffness::Array{Int32,2} 			## [nCellsx4]
	cell_clusters::Array{Int32,2} 			## [nNodesx8]
	node_stencils::Array{Float64,2} 		## [nNodesx8]
	node2cellsL2up::Array{Int32,2} 			## [nCellsx8]
	node2cellsL2down::Array{Int32,2} 		## [nCellsx8]
	cells2nodes::Array{Int32,2}
	VTKCells::Array{MeshCell,1}
	triangles::Array{Int32,2}
end


# @everywhere struct mesh2d_shared
	# mesh_connectivity::SharedArray{Int32,2} 	## [nCellsx3]
	# cell_mid_points::SharedArray{Float64,2} 		## [nCellsx2]
	# cell_areas::SharedVector{Float64} 			## [nCellsx1] 
	# Z::SharedVector{Float64} 					## [nCellsx1] 1/cell_areas
	# HX::SharedVector{Float64} 					## [nCellsx1] max edge length in  CV
	# cell_edges_Nx::SharedArray{Float64,2} 		## [nCellsx4]
	# cell_edges_Ny::SharedArray{Float64,2} 		## [nCellsx4]
	# cell_edges_length::SharedArray{Float64,2} 	## [nCellsx4]
	# cell_stiffness::SharedArray{Int32,2} 		## [nCellsx4]
	# cell_clusters::Array{Int32,2} 			## [nNodesx8]
	# node_stencils::Array{Float64,2} 		## [nNodesx8]
	# node2cellsL2up::SharedArray{Int32,2} 		## [nCellsx8]
	# node2cellsL2down::SharedArray{Int32,2} 		## [nCellsx8]
	# cells2nodes::SharedArray{Int32,2} 		    ## [nCellsx8]
# end


# @everywhere struct mesh2d_shared
	# mesh_connectivity::SharedArray{Int64,2} 	## [nCellsx3]
	# Z::SharedVector{Float64} 					## [nCellsx1] 1/cell_areas
	# cell_edges_Nx::SharedArray{Float64,2} 		## [nCellsx4]
	# cell_edges_Ny::SharedArray{Float64,2} 		## [nCellsx4]
	# cell_edges_length::SharedArray{Float64,2} 	## [nCellsx4]
	# cell_stiffness::SharedArray{Int64,2} 		## [nCellsx4]
	# node2cellsL2up::SharedArray{Int64,2} 				## [nCellsx8]
	# node2cellsL2down::SharedArray{Int64,2} 			## [nCellsx8]
# end

# @everywhere struct mesh2d
	# nCells::Int64
	# nNodes::Int64
	# nNeibCells::Int64						## max number of neighbors 
	# nBSets::Int64							##  number of boundaries  
	# xNodes::Array{Float64,1} 				##  mesh_nodes[nNodesx3]
	# yNodes::Array{Float64,1} 				##	mesh_nodes[nNodesx3]
	# mesh_connectivity::Array{Int64,2} 		## [nCellsx7]
	# bc_data::Array{Int64,2}
	# bc_indexes::Array{Int64,1}
	# cell_nodes_X::Array{Float64,2} 			## [nCellsx4]
	# cell_nodes_Y::Array{Float64,2} 			## [nCellsx4]
	# cell_mid_points::Array{Float64,2} 		## [nCellsx2]
	# cell_areas::Array{Float64,1} 			## [nCellsx1]
	# HX::Array{Float64,1}
	# Z::Array{Float64,1} 					## [nCellsx1] 1/cell_areas
	# cell_edges_Nx::Array{Float64,2} 		## [nCellsx4]
	# cell_edges_Ny::Array{Float64,2} 		## [nCellsx4]
	# cell_edges_length::Array{Float64,2} 	## [nCellsx4]
	# cell_stiffness::Array{Int64,2} 			## [nCellsx4]
	# cell_clusters::Array{Int64,2} 			## [nNodesx8]
	# node_stencils::Array{Float64,2} 		## [nNodesx8]
	# maxArea::Float64
	# maxEdgeLength::Float64
	# VTKCells::Array{MeshCell,1}
	# node2cellsL2up::Array{Int64,2} 			## [nCellsx8]
	# node2cellsL2down::Array{Int64,2} 		## [nCellsx8]
	# cells2nodes::Array{Int64,2}
# end

@everywhere mutable struct solutionCellsT
	dt::Float64
	flowTime::Float64
	nCells::Int64
	densityCells::Array{Float64,1}
	UxCells::Array{Float64,1}
	UyCells::Array{Float64,1}
	pressureCells::Array{Float64,1}
end

# flux approximation:
#  1 - AUSM+
#  2 - exact Riemann solver
#  3 - hybrid, AUSM + RB

# flux limiter:
#  1 - minmod 
#  2 - van Leer

# spatial approximation
#  1 - First order upwind;
#  2 - Second order upwind

#  spatial approximation
#  1 - 2nd order TVD RK 
#  2 - 3rd order TVD RK (depricated)
#  3 - 4th order general compact RK


@everywhere struct SOLVER2D
	FLUXtype::Int8
	FLUXlimiter::Int8
	SpatialDiscretization::Int8
	TimeDiscretization::Int8
end

@everywhere struct CONTROLS
	CFL::Float64
	dt::Float64 # time step
	timeStepMethod::Int8  # fixed or #adaptive
	startTime::Float64 # actual physical time to start simulation
	stopTime::Float64 # actual physical time to stop simulation 
	plotResidual::Int8 # flag to plot residuals
	densityConstrained::Int8 # flag to constrain density
	minDensityConstrained::Float64
	maxDensityConstrained::Float64
end

@everywhere struct plotCONTROLS
	contoursType::Int8 # 0 - filled contours , 1 - contour lines only
	nContours::Int8 # number of contours to plot 
	rhoMINcont::Float64 #min density
	rhoMAXcont::Float64 #max density 
	productionVideo::Int8 # flag to production video 
end


@everywhere struct outputCONTROLS
	verbosity::Int16
	header::String 
	saveResiduals::Int8
	saveResults::Int8
	fileNameResults::String
	fileNameResiduals::String
	saveDataToVTK::Int8
	fileNameVTK::String
end

@everywhere mutable struct DYNAMICCONTROLS
	flowTime::Float64 # actual physical time
	cpuTime::Float64 # cpu time
	tau::Float64 # tau 
	verIter::Int64 # iterator for verbosity (output)
	curIter::Int64 # global iterator for time steppings
	rhoMax::Float64 #max denisty in domain
	rhoMin::Float64 #min density in domain;
	velmax::Float64 #max velocity in domain
    globalPath::String # loacl path to the code
	localTestPath::String #path to the test 
	isSolutionConverged::Int8 # flag to show if the convergence criteria is satisfied
	isRunSimulation::Int8  # flag to run or stop Simulation
end
