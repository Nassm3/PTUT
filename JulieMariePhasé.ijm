//phase 1 du worflow JulieMarie
//il y a 7 phases
//in : image avec le signal des contours ouverte (488 nm)
//attention le contraste doit etre suffisament elevé fond autour de NG=10
//utiliser image adjust contrast si necessaire
//out: meme stack filtré
//temps d'exécution ~30 min pour 1003x1433x334 images 16 bits
//ver1.0

Poissons_zebre();

function Phase1(){
	selectWindow("488.tif");
	run("Gaussian Blur...", "sigma=1 stack");
	run("Subtract Background...", "rolling=50 stack");
	run("Anisotropic Anomalous Diffusion 2D Filter", "apply anomalous=1.0000 condutance=15.0000 time=0.1250 number=5 edge=Exponential");
	rename("ADD.tif");
	selectWindow("488.tif");
	close();
}

function Phase2(){
	selectWindow("ADD.tif");
	run("Morphological Segmentation");
	selectWindow("Morphological Segmentation"); // Activates the window with the title "Morphological Segmentation".
	wait(1000);
	call("inra.ijpb.plugins.MorphologicalSegmentation.segment", "tolerance=10.0", "calculateDams=true", "connectivity=6"); // Appele une méthode statique 
	// passant un nombre arbitraire d'arguments de chaîne et renvoyant une chaîne.
	log_index = -1;
	while (log_index == -1) {
		cont_log = getInfo("log"); //Returns the contents of the Log window, or "" if the Log window is not open.
		wait(2000);
		log_index = cont_log.indexOf("Whole");
	}
}

function Phase3(){
	selectWindow("Morphological Segmentation");
	call("inra.ijpb.plugins.MorphologicalSegmentation.setDisplayFormat", "Catchment basins");
	wait(2000);
	//selectWindow("ADD-catchment-basins.tif");
	wait(2000);
	call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
	wait(2000);
	selectWindow("Morphological Segmentation");
	close();
}

function Phase4(){
	selectWindow("ADD-catchment-basins.tif");
	run("Options...", "iterations=1 count=1 black do=Nothing");
	run("Set Measurements...", "area centroid perimeter shape stack limit redirect=None decimal=3");
	run("Duplicate...", "title=mask duplicate");
	run("Subtract...", "value=1 stack");
	run("16-bit");
	resetMinAndMax();
	setThreshold(1, 65535);
	run("Analyze Particles...", "size=200-Infinity show=Masks exclude stack");
	run("Invert LUT");
	run("16-bit");
	run("Multiply...", "value=400.000 stack");
	imageCalculator("AND create stack", "Mask of mask","ADD-catchment-basins.tif");
	rename("bassin-filtered.tif");
	//clean
	selectWindow("Mask of mask");
	close();
	selectWindow("mask");
	close();
	selectWindow("ADD-catchment-basins.tif");
	close();
}


function Phase5(){
	// showMessage("l'image acquise sur canal 561 nm doit etre ouverte-marquage avec les ARNs et les contours");
	selectWindow("561.tif");
	p = 30;
	getDimensions(width, height, channels, slices, frames); // Returns the dimensions of the current image.
	setSlice((floor(slices/2))); // Affiche la nième tranche/slices de la pile active (celle du milieu ici).
	run("Enhance Contrast", "saturated=0.35"); // améliorer le contraste local d'une image
	run("8-bit");
	run("Gaussian Blur...", "sigma=2 stack"); // réduit le bruit
	
	n = nSlices; // Returns the number of images in the current stack.
	name = getTitle();
	for(i=1;i<=n;i++){
		selectWindow(name);
		setSlice(i); // Affiche la iième tranche de la pile active.
		run("Find Maxima...", "prominence="+p+" output=[Single Points]");
		}
	//Make stack from image named with "Maxima"
	run("Images to Stack", "method=[Copy (center)] name=Stack title=Maxima use"); // Images to Stack
	run("Options...", "iterations=1 count=1 black do=Dilate stack");
}

function Phase6(){
	selectWindow("Stack");
	rename("origine");
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	run("3D Objects Counter", "threshold=128 slice=48 min.=3 max.=64995840 centroids");
	selectWindow("Centroids map of origine");
	setThreshold(1, 65534);
	setOption("BlackBackground", true);
	run("Convert to Mask", "method=Default background=Dark black");
	run("Set Measurements...", "centroid stack redirect=None decimal=3");
	run("Analyze Particles...", "display clear stack");
	
	//clean
	selectWindow("origine");
	close();
	selectWindow("Centroids map of origine");
	close();
}

function Phase7(){
	selectWindow("bassin-filtered.tif");
	for (row = 0; row < nResults; row++) {
		x=floor(getResult("X", row));
		y=floor(getResult("Y", row));
		setSlice(floor(getResult("Slice", row)));
		setResult("CellNumber", row, getPixel(x, y));
	}
	
	//This part count for each cell the number of dots included
	SpotInCellsCount=newArray(nResults);
	n=SpotInCellsCount.length;
	Array.fill(SpotInCellsCount,0);
	
	for (row = 0; row < n; row++) {
		a=getResult("CellNumber", row);
		SpotInCellsCount[a]++;
	}
	indexOfCell=Array.getSequence(n);
	Array.show(indexOfCell,SpotInCellsCount);
	// if macro erreur fenètre ouverte --> afficher un message qui explique l'erreur (c'est dû aux mauvais résultats)
}

function Poissons_zebre(){
	print("#### Début Phase 1 ####");
	Phase1();
	print("#### Phase 1 terminée ####");
	print("#### Début Phase 2 ####");	
	Phase2();
	print("#### Phase 2 terminée ####");
	print("#### Début Phase 3 ####");	
	Phase3();
	print("#### Phase 3 terminée ####");
	print("#### Début Phase 4 ####");	
	Phase4();
	print("#### Phase 4 terminée ####");	
	Phase5();
	print("#### Phase 5 terminée ####");	
	Phase6();
	print("#### Phase 6 terminée ####");
	Phase7();
	print("#### Phase 7 terminée ####");
}






