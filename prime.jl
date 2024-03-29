

using Distributed;
using PyPlot;

using WriteVTK;
using CPUTime;
using DelimitedFiles;
using Printf
using BSON: @load
using BSON: @save
using SharedArrays;

using HDF5;
using ProfileView;
using CUDA;


include("primeObjects.jl");
include("thermo.jl"); #setup thermodynamics
include("utilsIO.jl");


include("AUSMflux2dFast.jl"); #AUSM+ inviscid flux calculation 
include("RoeFlux2dFast.jl");
include("AUSMflux2dCUDA.jl");
include("AUSMflux2dCUDAx32.jl");
include("RoeFlux2dCUDA.jl");

include("utilsFVM2dp.jl"); #FVM utililities
## utilsFVM2dp::cells2nodesSolutionReconstructionWithStencilsImplicitSA
## utilsFVM2dp::cells2nodesSolutionReconstructionWithStencilsSA
## utilsFVM2dp::phs2dcns2dcellsSA

include("partMesh2d.jl");

include("calcGrad.jl");
include("calcDiv.jl");
#include("calcArtViscosity.jl");
include("calcDiffterm.jl");

include("bcInviscidWall.jl"); 

include("createViscousFields.jl")
#include("boundaryConditions_jet2d.jl");
#include("initfields_jet2d.jl");

include("loadPrevResults.jl");

#include("boundaryConditions_ML2d.jl");
#include("initfields_ML2d.jl");

include("boundaryConditions_cyl2d.jl");
include("initfields_cyl2d.jl");



## initfields2d::distibuteCellsInThreadsSA()
## initfields2d::createFields2d_shared()

include("evaluate2d.jl"); 
## propagate2d::updateResidualSA()
## propagate2d::updateVariablesSA()
## propagate2d::updateOutputSA()


##include("computeslope2d.jl");
#include("SOUscheme.jl");


include("limiters.jl");
include("computeslope2d.jl");
include("SOUscheme.jl");


## computeslope2d:: computeInterfaceSlope()
## SOUscheme:: SecondOrderUpwindM2()

include("propagate2d.jl");
## propagate:: calcOneStage() expilict Euler first order
## propagate:: doExplicitRK3TVD() expilict RK3-TVD



function ksi(r::Float64, a::Float64, b::Float64, rs::Float64, re::Float64)::Float64

	## rb = (r-rs)/(re-rs)
	return (1.0 - a*(r-rs)/(re-rs)*(r-rs)/(re-rs))* (1.0 - (1.0 - exp(b*(r-rs)/(re-rs)*(r-rs)/(re-rs)))/(1.0 - exp(b)));
end


function godunov2dthreads(pname::String, outputfile::String, coldrun::Bool)


	useCuda = false;
	debug = true;	
	viscous = true;
	damping = false;
	flag2loadPreviousResults = false;
	GPU32_inviscid = true;



	testMesh = readMesh2dHDF5(pname);
		
	cellsThreads = distibuteCellsInThreadsSA(Threads.nthreads(), testMesh.nCells); ## partition mesh 
	nodesThreads = distibuteNodesInThreadsSA(Threads.nthreads(), testMesh.nNodes); ## partition mesh 
	

	#include("setupSolver_ML2d.jl"); #setup FVM and numerical schemes
	#include("setupSolver_jet2d.jl"); #setup FVM and numerical schemes
	include("setupSolver_cyl2d.jl"); #setup FVM and numerical schemes
	
	
	## init primitive variables 
	println("set initial and boundary conditions ...");
	
	
	#testfields2d = createFields2d_shared(testMesh, thermo);
	testfields2d = createFields2d(testMesh, thermo);
	
	solInst = solutionCellsT(
		0.0,
		0.0,
		testMesh.nCells,
		testfields2d.densityCells,
		testfields2d.UxCells,
		testfields2d.UyCells,
		testfields2d.pressureCells,
	);
	
	
	if (flag2loadPreviousResults)
		loadPrevResults(testMesh, thermo, "jet2d_v03tri.tmp", dynControls, testfields2d);
	end
	
	
	
	#viscfields2d = createViscousFields2d_shared(testMesh.nCells, testMesh.nNodes);
	viscfields2d = createViscousFields2d(testMesh.nCells, testMesh.nNodes);
	
	println("nCells:\t", testMesh.nCells);
	println("nNodes:\t", testMesh.nNodes);
	
	## init conservative variables 	
	
	UconsCellsOldX = zeros(Float64,testMesh.nCells,4);
	UconsNodesOldX = zeros(Float64,testMesh.nNodes,4);
	UconsCellsNewX = zeros(Float64,testMesh.nCells,4);
		
	UConsDiffCellsX = zeros(Float64,testMesh.nCells,4);
	UConsDiffNodesX = zeros(Float64,testMesh.nNodes,4);
	
	DeltaX = zeros(Float64,testMesh.nCells,4);
	iFLUXX  = zeros(Float64,testMesh.nCells,4);
	dummy  = zeros(Float64,testMesh.nNodes,4);

	uRight1 = zeros(Float64,4,testMesh.nCells);
	uRight2 = zeros(Float64,4,testMesh.nCells);
	uRight3 = zeros(Float64,4,testMesh.nCells);
	uRight4 = zeros(Float64,4,testMesh.nCells);

	uLeft = zeros(Float64,4,testMesh.nCells);

	iFluxV1 = zeros(Float64,testMesh.nCells);
	iFluxV2 = zeros(Float64,testMesh.nCells);
	iFluxV3 = zeros(Float64,testMesh.nCells);
	iFluxV4 = zeros(Float64,testMesh.nCells);
	
	###################################################################################
	## Vectors for CUDA 

	if (GPU32_inviscid)
		include("cuda_data_x32.jl")
	else
		include("cuda_data_x64.jl")
	end

	
	
	
	
	###################################################################################
	
	phs2dcns2dcellsSA(UconsCellsOldX,testfields2d, thermo.Gamma);	
	phs2dcns2dcellsSA(UconsCellsNewX,testfields2d, thermo.Gamma);	
	
	
	cells2nodesSolutionReconstructionWithStencilsUCons(nodesThreads, testMesh, UconsCellsOldX,  UconsNodesOldX );	

	

	timeVector = [];
	residualsVector1 = []; 
	residualsVector2 = []; 
	residualsVector3 = []; 
	residualsVector4 = []; 
	residualsVectorMax = ones(Float64,4);
	convergenceCriteria= [1e-5;1e-5;1e-5;1e-5;];
	
	
	# debugSaveInit = false;
	# if (debugSaveInit)
	
		# rhoNodes = zeros(Float64,testMesh.nNodes);
		# uxNodes = zeros(Float64,testMesh.nNodes);
		# uyNodes = zeros(Float64,testMesh.nNodes);
		# pNodes = zeros(Float64,testMesh.nNodes);
	
		# cells2nodesSolutionReconstructionWithStencilsImplicitSA(nodesThreadsX, testMeshDistrX, testfields2dX, dummy); 
	
		# for i = 1:testMesh.nNodes
			# rhoNodes[i] = testfields2dX.densityNodes[i];
			# uxNodes[i] = testfields2dX.UxNodes[i];
			# uyNodes[i] = testfields2dX.UyNodes[i];
			# pNodes[i] = testfields2dX.pressureNodes[i];
		# end
		
		# outputfileZero = string(outputfile,"_t=0");
		# println("Saving  solution to  ", outputfileZero);
			# #saveResults2VTK(outputfile, testMesh, densityF);
			# saveResults4VTK(outputfileZero, testMesh, rhoNodes, uxNodes, uyNodes, pNodes);
		# println("done ...  ");	
		
		
		# @save outputfileZero solInst
		
	# end
	
	
	
	maxEdge,id = findmax(testMesh.HX);

	dt::Float64 =  solControls.dt;  
	# @everywhere dtX = $dt; 
	# @everywhere maxEdgeX = $maxEdge; 

	
	UconsRef = zeros(4);
	UconsRef[1] = 1.1766766855256956;
	UconsRef[2] = 1.1766766855256956*19.964645104094163;
	UconsRef[3] = 0.0;
	UconsRef[4] = 101325.0/(thermo.Gamma -1.0) + 0.5*1.1766766855256956*(19.964645104094163*19.964645104094163 + 0.0*0.0);

	
	println("Start calculations ...");
	println(output.header);
	
	##if (!coldrun)
	
	
		#for l = 1:2
		while (dynControls.isRunSimulation == 1)
		
			
			##CPUtic();	
			start = time();
			
			
			# PROPAGATE STAGE: 
			(dynControls.velmax,id) = findmax(testfields2d.VMAXCells);
			# #dynControls.tau = solControls.CFL * testMesh.maxEdgeLength/(max(dynControls.velmax,1.0e-6)); !!!!
			dynControls.tau = solControls.CFL * maxEdge/(max(dynControls.velmax,1.0e-6));
		
			
			if (viscous)
			
				#calcArtificialViscositySA( cellsThreads, testMesh, thermo, testfields2d, viscfields2d);		
				calcDiffTerm(cellsThreads, nodesThreads, testMesh, testfields2d, viscfields2d, thermo, UconsNodesOldX, UConsDiffCellsX);
			
			end
	

			if (CUDA.has_cuda() && useCuda)
			

			 	 calcOneStageCUDA(1.0, solControls.dt, dynControls.flowTime, 
				 		testMesh , testfields2d, thermo, cellsThreads,  
				 		UconsCellsOldX, UConsDiffCellsX,  UconsCellsNewX, 
			 	 		uLeft, 
						uRight1, uRight2, uRight3, uRight4,
						iFluxV1, iFluxV2, iFluxV3, iFluxV4, 
						curLeftV, cuULeftV, cuVLeftV, cuPLeftV, 
						curRightV, cuURightV, cuVRightV, cuPRightV, 
					  	cuNxV1234, #cuNxV1, cuNxV2, cuNxV3, cuNxV4, 
						cuNyV1234, #cuNyV1, cuNyV2, cuNyV3, cuNyV4, 
						cuSideV1234, #cuSideV1, cuSideV2, cuSideV3, cuSideV4,
					  	cuFluxV1, cuFluxV2, cuFluxV3, cuFluxV4,  
						cuNeibsV);


			else

			 	## Explicit Euler first-order	
			 	## calcOneStage(1.0, solControls.dt, dynControls.flowTime, testMesh , testfields2d, thermo, cellsThreads,  UconsCellsOldX, iFLUXX, UConsDiffCellsX,  UconsCellsNewX);

				Threads.@threads for p in 1:Threads.nthreads()	
					SecondOrderUpwindM2(cellsThreads[p,1], cellsThreads[p,2], 1.0, solControls.dt, dynControls.flowTime,  
						testMesh, testfields2d, thermo, UconsCellsOldX, iFLUXX, UConsDiffCellsX,  UconsCellsNewX);
				end

			end


			if (damping)

				Threads.@threads for p in 1:Threads.nthreads()
					for i = cellsThreads[p,1]:cellsThreads[p,2]
						
						# calc rad = sqrt(x*x + yy)
						r::Float64 = sqrt(testMesh.cell_mid_points[i,1]*testMesh.cell_mid_points[i,1]  + testMesh.cell_mid_points[i,2]*testMesh.cell_mid_points[i,2] ); 

						if r >= 2.5
							#UconsCellsNewX[i,1] = 	UconsRef[1] - ksi(r,0.1,20.0,2.0,4.0)*( UconsCellsNewX[i,1] - UconsRef[1]) ;
							#UconsCellsNewX[i,2] = 	UconsRef[2] - ksi(r,0.1,20.0,2.0,4.0)*( UconsCellsNewX[i,2] - UconsRef[2]) ;
							#UconsCellsNewX[i,3] = 	UconsRef[3] - ksi(r,0.1,20.0,2.0,4.0)*( UconsCellsNewX[i,3] - UconsRef[3]) ;
							#UconsCellsNewX[i,4] = 	UconsRef[4] - ksi(r,0.1,20.0,2.0,4.0)*( UconsCellsNewX[i,4] - UconsRef[4]) ;

							UconsCellsNewX[i,1] = 	ksi(r,0.1,20.0,2.5,4.0)* UconsCellsNewX[i,1] + (1.0-ksi(r,0.1,20.0,2.5,4.0))*UconsRef[1] ;
							UconsCellsNewX[i,2] = 	ksi(r,0.1,20.0,2.5,4.0)* UconsCellsNewX[i,2] + (1.0-ksi(r,0.1,20.0,2.5,4.0))*UconsRef[2] ;
							UconsCellsNewX[i,3] = 	ksi(r,0.1,20.0,2.5,4.0)* UconsCellsNewX[i,3] + (1.0-ksi(r,0.1,20.0,2.5,4.0))*UconsRef[3] ;
							UconsCellsNewX[i,4] = 	ksi(r,0.1,20.0,2.5,4.0)* UconsCellsNewX[i,4] + (1.0-ksi(r,0.1,20.0,2.5,4.0))*UconsRef[4] ;

						end
					
					end
				end

			end
			
			#doExplicitRK3TVD(1.0, dtX, testMeshDistrX , testfields2dX, thermoX, cellsThreadsX,  UconsCellsOldX, iFLUXX,  UConsDiffCellsX, 
			#  UconsCellsNew1X,UconsCellsNew2X,UconsCellsNew3X,UconsCellsNewX);
			
			
			if (solControls.densityConstrained==1)

				Threads.@threads for p in 1:Threads.nthreads()
					for i = cellsThreads[p,1]:cellsThreads[p,2]
						
						if  UconsCellsNewX[i,1] >= solControls.maxDensityConstrained
							UconsCellsNewX[i,1] = solControls.maxDensityConstrained;
						end		
						if  UconsCellsNewX[i,1] <= solControls.minDensityConstrained
							UconsCellsNewX[i,1] = solControls.minDensityConstrained;
						end		

					end
				end
			end

			(dynControls.rhoMax,id) = findmax(testfields2d.densityCells);
			(dynControls.rhoMin,id) = findmin(testfields2d.densityCells);

			
			#@sync @distributed for p in workers()
			Threads.@threads for p in 1:Threads.nthreads()			
	
				#beginCell::Int32 = cellsThreads[p,1];
				#endCell::Int32 = cellsThreads[p,2];
				#println("worker: ",p,"\tbegin cell: ",beginCell,"\tend cell: ", endCell);										
				#updateVariablesSA(beginCell, endCell, thermo.Gamma,  UconsCellsNewX, UconsCellsOldX, DeltaX, testfields2d);
				updateVariablesSA(cellsThreads[p,1], cellsThreads[p,2], thermo.Gamma,  UconsCellsNewX, UconsCellsOldX, DeltaX, testfields2d);
		
			end
			
			
			
			
			 #@sync @distributed for p in workers()	
			 Threads.@threads for p in 1:Threads.nthreads()
	
				#  beginNode::Int32 = nodesThreads[p,1];
				#  endNode::Int32 = nodesThreads[p,2];														
				#  cells2nodesSolutionReconstructionWithStencilsDistributed(beginNode, endNode, 
				# 	testMesh, testfields2d, viscfields2d, UconsCellsOldX,  UconsNodesOldX);
				cells2nodesSolutionReconstructionWithStencilsDistributed(nodesThreads[p,1],nodesThreads[p,2],
				 	testMesh, testfields2d, viscfields2d, UconsCellsOldX,  UconsNodesOldX);
		
			 end
			
			
			
			
			#cells2nodesSolutionReconstructionWithStencilsSerial(testMeshX,testfields2dX, viscfields2dX, UconsCellsOldX,  UconsNodesOldX);
								
	
			

			push!(timeVector, dynControls.flowTime); 
			dynControls.curIter += 1; 
			dynControls.verIter += 1;
				
			
			
			
			updateResidualSA(DeltaX, 
				residualsVector1,residualsVector2,residualsVector3,residualsVector4, residualsVectorMax,  
				convergenceCriteria, dynControls);
			
			
			updateOutputSA(timeVector,residualsVector1,residualsVector2,residualsVector3,residualsVector4, residualsVectorMax, 
				testMesh, testfields2d, viscfields2d,  solControls, output, dynControls, solInst);
	
			
			# EVALUATE STAGE:
			
			dynControls.flowTime += dt; 
			##flowTimeX += dt;
			
			# if (solControlsX.timeStepMethod == 1)
				# dynControlsX.flowTime += dynControlsX.tau;  	
			# else
				# dynControlsX.flowTime += solControlsX.dt;  
			# end
			

	
			if (flowTime>= solControls.stopTime || dynControls.isSolutionConverged == 1) 
			#if (flowTime>= solControls.stopTime)
				dynControls.isRunSimulation = 0;
		
				if (dynControls.isSolutionConverged == true)
					println("Solution converged! ");
				else
					println("Simultaion flow time reached the set Time!");
				end
			
				if (output.saveResiduals == 1)
					#println("Saving Residuals ... ");
					#cd(dynControlsX.localTestPath);
					#saveResiduals(output.fileNameResiduals, timeVector, residualsVector1, residualsVector2, residualsVector3, residualsVector4);
					#cd(dynControlsX.globalPath);
				end
				if (output.saveResults == 1)
					#println("Saving Results ... ");
					#cd(dynControlsX.localTestPath);
					#saveSolution(output.fileNameResults, testMeshX.xNodes, testMeshX.yNodes, UphysNodes);
					#cd(dynControlsX.globalPath);
				end
			
				
			
			end

			#dynControlsX.cpuTime  += CPUtoq(); 
			elapsed = time() - start;
			dynControls.cpuTime  += elapsed ; 
			
			if (dynControls.flowTime >= solControls.stopTime)
				dynControls.isRunSimulation = 0;
			end
			
		end ## end while
		 
		 
		
		
		solInst.dt = solControls.dt;
		solInst.flowTime = dynControls.flowTime;
		for i = 1 : solInst.nCells
		 	solInst.densityCells[i] 	= testfields2d.densityCells[i];
		 	solInst.UxCells[i] 			= testfields2d.UxCells[i];
		 	solInst.UyCells[i] 			= testfields2d.UyCells[i];
		 	solInst.pressureCells[i] 	= testfields2d.pressureCells[i];
		end
		

		rhoNodes = zeros(Float64,testMesh.nNodes);
		uxNodes = zeros(Float64,testMesh.nNodes);
		uyNodes = zeros(Float64,testMesh.nNodes);
		pNodes = zeros(Float64,testMesh.nNodes);
	
		cells2nodesSolutionReconstructionWithStencilsImplicitSA(nodesThreads, testMesh, testfields2d, dummy); 
	
		for i = 1:testMesh.nNodes
			rhoNodes[i] 		= testfields2d.densityNodes[i];
			uxNodes[i] 			= testfields2d.UxNodes[i];
			uyNodes[i] 			= testfields2d.UyNodes[i];
			pNodes[i] 			= testfields2d.pressureNodes[i];
		end
				
		println("Saving  solution to  ", outputfile);
			saveResults4VTK(outputfile, testMesh, rhoNodes, uxNodes, uyNodes, pNodes);
			@save outputfile solInst
		println("done ...  ");	
		
		 
		 
		
	#end ## if debug
	
end



#godunov2dthreads("2mixinglayer_1200x480", "2mixinglayer_1200x480", false); 
#godunov2dthreads("2mixinglayer_1800x720q", "2mixinglayer_1800x720q", false); 
#godunov2dthreads("2dmixinglayerUp_delta3",  "2dmixinglayerUp_delta3", false); 

#godunov2dthreads("jet2d_v03tri",  "jet2d_v03tri", false); 
godunov2dthreads("cyl2d_laminar_test",  "cyl2d_laminar_test", false); 




