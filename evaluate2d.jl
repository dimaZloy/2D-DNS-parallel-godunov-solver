




@everywhere function updateResidualSA(
	Delta::Array{Float64,2},
	residualsVector1::Array{Any,1},
	residualsVector2::Array{Any,1},
	residualsVector3::Array{Any,1},
	residualsVector4::Array{Any,1},
	residualsVectorMax::Array{Float64,1},
	convergenceCriteria::Array{Float64,1},
	dynControls::DYNAMICCONTROLS,
	)

	residuals1::Float64   =sum( Delta[:,1].*Delta[:,1] );
	residuals2::Float64  = sum( Delta[:,2].*Delta[:,2] );
	residuals3::Float64  = sum( Delta[:,3].*Delta[:,3] );
	residuals4::Float64  = sum( Delta[:,4].*Delta[:,4] );
	
	push!(residualsVector1, residuals1);
	push!(residualsVector2, residuals2);
	push!(residualsVector3, residuals3);
	push!(residualsVector4, residuals4);
	
	if (dynControls.curIter<6 && dynControls.curIter>1)

   		(residualsVectorMax[1],id1) = findmax(residualsVector1[1:dynControls.curIter]);	
   		(residualsVectorMax[2],id2) = findmax(residualsVector2[1:dynControls.curIter]);		
   		(residualsVectorMax[3],id3) = findmax(residualsVector3[1:dynControls.curIter]);		
   		(residualsVectorMax[4],id4) = findmax(residualsVector4[1:dynControls.curIter]);		

	end

	if ( (dynControls.curIter>5) && 
    	(residualsVector1[dynControls.curIter]./residualsVectorMax[1] <= convergenceCriteria[1]) &&
     	(residualsVector2[dynControls.curIter]./residualsVectorMax[2] <= convergenceCriteria[2]) &&
     	(residualsVector3[dynControls.curIter]./residualsVectorMax[3] <= convergenceCriteria[3]) &&
     	(residualsVector4[dynControls.curIter]./residualsVectorMax[4] <= convergenceCriteria[4]) )

	 	dynControls.isSolutionConverged  = 1; 

	end



end




@everywhere function updateVariablesSA(
	beginCell::Int32,endCell::Int32, CFL::Float64,
	thermo::THERMOPHYSICS, ## Gamma::Float64,
	 UconsCellsNew::Array{Float64,2},
	 UconsCellsOld::Array{Float64,2},
	 Delta::Array{Float64,2},
	 testMesh::mesh2d_Int32,
	 testfields2d::fields2d,
	 viscfields2d::viscousFields2d)
	
	for i=beginCell:endCell
	
		# if UconsCellsNew[i,1] < 0.01
			# testfields2d.densityCells[i] = 0.01;
		# elseif UconsCellsNew[i,1] > 10.0
			# testfields2d.densityCells[i] = 10.0;
		# else
			# testfields2d.densityCells[i] = UconsCellsNew[i,1];
		# end
		
		testfields2d.densityCells[i] = UconsCellsNew[i,1];
		
		testfields2d.UxCells[i] 	  = UconsCellsNew[i,2]/UconsCellsNew[i,1];
		testfields2d.UyCells[i] 	  = UconsCellsNew[i,3]/UconsCellsNew[i,1];
		testfields2d.pressureCells[i] = (thermo.Gamma-1.0)*( UconsCellsNew[i,4] - 0.5*( UconsCellsNew[i,2]*UconsCellsNew[i,2] + UconsCellsNew[i,3]*UconsCellsNew[i,3] )/UconsCellsNew[i,1] );
		
		testfields2d.temperatureCells[i] 	= testfields2d.pressureCells[i]/testfields2d.densityCells[i]/ thermo.RGAS;

		testfields2d.aSoundCells[i] = sqrt( thermo.Gamma * testfields2d.pressureCells[i]/testfields2d.densityCells[i] );
		testfields2d.VMAXCells[i]  = sqrt( testfields2d.UxCells[i]*testfields2d.UxCells[i] + testfields2d.UyCells[i]*testfields2d.UyCells[i] ) + testfields2d.aSoundCells[i];
		
		testfields2d.kCells[i] 	= thermo.kFromT(testfields2d.temperatureCells[i]);
		testfields2d.gammaCells[i] = thermo.gammaFromT(testfields2d.temperatureCells[i]);
		
		
		testfields2d.localCFLCells[i] = min(CFL*0.5*testMesh.HX[i]/testfields2d.VMAXCells[i], 
								testMesh.HX[i]*testMesh.HX[i]*0.25*testfields2d.densityCells[i]/viscfields2d.artViscosityCells[i]);
				
		Delta[i,1] = UconsCellsNew[i,1] - UconsCellsOld[i,1];
		Delta[i,2] = UconsCellsNew[i,2] - UconsCellsOld[i,2];
		Delta[i,3] = UconsCellsNew[i,3] - UconsCellsOld[i,3];
		Delta[i,4] = UconsCellsNew[i,4] - UconsCellsOld[i,4];

		
		UconsCellsOld[i,1] = UconsCellsNew[i,1];
		UconsCellsOld[i,2] = UconsCellsNew[i,2];
		UconsCellsOld[i,3] = UconsCellsNew[i,3];
		UconsCellsOld[i,4] = UconsCellsNew[i,4];
		
	end
	
 end








@everywhere function updateOutputSA(
	timeVector::Array{Any,1},
	residualsVector1::Array{Any,1},
	residualsVector2::Array{Any,1},
	residualsVector3::Array{Any,1},
	residualsVector4::Array{Any,1},
	residualsVectorMax::Array{Float64,1}, 
	testMesh::mesh2d_Int32,
	testFields::fields2d,
	testFieldsViscous::viscousFields2d,
	solControls::CONTROLS,
	output::outputCONTROLS,
	dynControls::DYNAMICCONTROLS,
	solInst::solutionCellsT,
	wallNodes::Vector{Int32},
	wallDistances::Vector{Float64},
	wallCells::Vector{Int32},
	cfNodes::Vector{Float64},
	yPlusNodes::Vector{Float64}
	)

	if (dynControls.verIter == output.verbosity)


		densityWarn = @sprintf("Density Min/Max: %f/%f", dynControls.rhoMin, dynControls.rhoMax);
		out = @sprintf("%0.10f\t %0.10f \t %0.6f \t %0.6f \t %0.6f \t %0.6f \t %0.6f", 
			dynControls.flowTime,
			dynControls.tau,
			residualsVector1[dynControls.curIter]./residualsVectorMax[1],
			residualsVector2[dynControls.curIter]./residualsVectorMax[2],
			residualsVector3[dynControls.curIter]./residualsVectorMax[3],
			residualsVector4[dynControls.curIter]./residualsVectorMax[4],
			dynControls.cpuTime
			 );
		#outputS = string(output, cpuTime);
		#println(outputS); 
		println(out); 
		println(densityWarn);
		
		
		
		
		if (output.saveDataToVTK == 1)
		
		
		
			solInst.dt = solControls.dt;
			solInst.flowTime = dynControls.flowTime;
			for i = 1 : solInst.nCells
				solInst.densityCells[i] = testFields.densityCells[i];
				solInst.UxCells[i] = testFields.UxCells[i];
				solInst.UyCells[i] = testFields.UyCells[i];
				solInst.pressureCells[i] = testFields.pressureCells[i];
			end
		
			filename = string("zzz",dynControls.curIter+1000); 	
			saveResults2VTK(filename, testMesh, testFields.densityNodes, "density");
			@save filename solInst
			
		end
		 
			
	
		if (solControls.plotResidual == 1)	


			
			subplot(3,2,1);	
			cla();
			
			##tricontourf(testMesh.xNodes,testMesh.yNodes, triangles, densityF,pControls.nContours,vmin=pControls.rhoMINcont,vmax=pControls.rhoMAXcont);
			tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, testFields.densityNodes);
			#tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, sqrt.(testFields.UxNodes.*testFields.UxNodes .+ testFields.UyNodes.*testFields.UyNodes));
			#colorbar();
			set_cmap("jet");
			xlabel("x");
			ylabel("y");
			title("Contours of density");
			axis("equal");

			subplot(3,2,2);	
			cla();
			
			
			#plot(exp_pressure[:,1],exp_pressure[:,2], "or",label="exp",markersize = 4.0);
			plot(testMesh.xNodes[wallNodes],testFields.pressureNodes[wallNodes]./50000.0, "sk",markersize = 2.0);
			# maxMu,id = findmax(testFieldsViscous.artViscosityNodes);
			# minMu,id = findmin(testFieldsViscous.artViscosityNodes);
			
			#tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, testFieldsViscous.artViscosityNodes, 25, vmin = minMu, vmax=maxMu);
			#tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, testFieldsViscous.cdUdyNodes);
			# tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, sqrt.(testFields.UxNodes.*testFields.UxNodes .+ testFields.UyNodes.*testFields.UyNodes));
			# colorbar();
			# #tricontourf(testMesh.xNodes,testMesh.yNodes, testMesh.triangles, localDampNodes);
		
			
			 grid();
			 xlabel("x");
			 ylabel("p/pinf");
			 title("p/Pinf");
			# axis("equal");
			
			
			
		
			
			 for i = 1:length(wallNodes)
				node = wallNodes[i];
				cell = wallCells[i];
				
				# #cf_Nodes[i] = 2.0/(0.5806*746.531*746.531)*testFieldsViscous.artViscosityNodes[z]*testFieldsViscous.cdUdyNodes[z];
				tauWall =  testFieldsViscous.artViscosityNodes[node]*testFields.UxCells[cell]/wallDistances[i];
				cfNodes[i] = 2.0/(0.5806*746.531*746.531)*tauWall;
				
				yPlusNodes[i] = wallDistances[i]/testFieldsViscous.artViscosityNodes[node]*testFields.densityNodes[node]*sqrt(abs(tauWall)/testFields.densityNodes[node]);
				
			 end
			
			subplot(3,2,3);
			cla();
			
			#plot(exp_cf[:,1],exp_cf[:,2], "or",label="exp",markersize = 2.0);
			plot(testMesh.xNodes[wallNodes],cfNodes, "sk",markersize = 2.0);
			grid();
			xlabel("x");
			ylabel("Cf");
			#title("p/Pinf");

			subplot(3,2,4);
			cla();
			
			#plot(exp_cf[:,1],exp_cf[:,2], "or",label="exp",markersize = 2.0);
			plot(testMesh.xNodes[wallNodes],yPlusNodes, "sk",markersize = 2.0);
			xlabel("x");
			ylabel("yPlus");
			grid();

			subplot(3,2,5);
			cla();

			
			if (size(timeVector,1) >1)
				plot(timeVector, residualsVector1./residualsVectorMax[1],"-r",label="continuity"); 
				plot(timeVector, residualsVector2./residualsVectorMax[2],"-g",label="momentum ux"); 
				plot(timeVector, residualsVector3./residualsVectorMax[3],"-b",label="momentum uy"); 
				plot(timeVector, residualsVector4./residualsVectorMax[4],"-c",label="energy"); 
			end
			
			yscale("log");	
			xlabel("flow time [s]");
			ylabel("Res");
			title("Residuals");
			legend();
			
			pause(1.0e-5);
			
			
		end

   

		#pause(1.0e-3);
		dynControls.verIter = 0; 

	end



end

