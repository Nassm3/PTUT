
Dialog.create("Conditions d'utilisation :");
Dialog.addMessage("    -Veuillez créer un dossier pour chaque embryon dans lequel se trouvera 3 dossiers pour chaque stade.(T1,T2 et T3) \n \n    -Dans chaque dossier stade, doit se trouver l'image 488 et l'image 561. Ainsi, il ne doit contenir que 2 éléments (488 et 561) \n \nPar exemple : \nEmbryon1/T1/488             ...pour l'embryon 1 au stade 1.");
Dialog.show();

repertoire_image=getDir("Veuillez séléctionner le repertoire contenant les images"); 	//récupération du chemin menant au repertoire des image, ex: C:\Users\nd202\Desktop\TEST\EMBRYON 1\T1\
chemin_stade=File.getParent(repertoire_image);  //récupération des repertoire contenant les différent stades et embryons
chemin_embryon=File.getParent(chemin_stade);

embryon=getFileList(chemin_embryon);	// récupération de la liste des dossier embryon et stade
stade=getFileList(chemin_stade);		//par exemple dans embryon si on a que 2 embryons, array.show(embryon) retourne EMBRYON 1/
																											//			EMBRYON 2/

Array.sort(stade);			//trie la liste des embryons au cas où il seraientt dans le désordre
Array.sort(embryon);

l=lengthOf(embryon);		//nombre d'embryons
for (i=0;i<l;i++) {	
	
	chemin_stade=chemin_embryon+"\\"+embryon[i];	//chemin_stade = chemin pour accéder au stade pour chaque embryons
	
	for (j=0;j<3;j++) {
													
		chemin_image=replace(chemin_stade+stade[j], "/", "\\");		 //chemin_image = C:\Users\nd202\Desktop\TEST\EMBRYON [i]\T[j]\
		
		image=replace(chemin_image, "\\", "\\\\");			//image = C:\\Users\\nd202\\Desktop\\TEST\\EMBRYON [i]\\T[j]\\
															//utilisation de double anti slash car sinon pour de specialiser le caractère '\' (sinon open() ne fonctionne pas)
		
		nb=getFileList(image);		//nb contient le nom des fichiers images

		Array.sort(nb);		// on met l'image 488 en premier 
		if (lengthOf(nb) == 2) {  // par précaution, il faut qu'il y ait seulement les images 488 et 561 dans le dossier 
			
			open(image+nb[1]);
			tif_561 = getTitle();

			open(image+nb[0]);//ouverture de 488 en dernier
			tif_488 = getTitle();

			Poissons_zebre();

			Table.save(image);

			close("*");		//fermeture des images une fois le programme exécuté
			
			//appeler la fonction poisson zebre puis fermer les images

		}
		else {
			showMessage("Le repertoire contenant les images doit contenir seulement 488 et 561 !");
		}
	}
}



function Phase1() {

	//in : image avec le signal des contours ouverte (488 nm)
	//attention le contraste doit etre suffisament elevé fond autour de NG=10
	//utiliser image adjust contrast si necessaire
	//out: meme stack filtré

	selectWindow("488.tif");
	// selectWindow(tif_488); // pour le programme final
	run("Gaussian Blur...", "sigma=1 stack");
	run("Subtract Background...", "rolling=50 stack");
	run("Anisotropic Anomalous Diffusion 2D Filter", "apply anomalous=1.0000 condutance=15.0000 time=0.1250 number=5 edge=Exponential");
	rename("ADD.tif");
	selectWindow(tif_488);
	close();
}

function Phase2() {

	//in : image avec le signal des contours fitres par la macro phase1 (normalement son nom est : ADD
	//out:  MorpholibJ-Morphological Segmentation plugin ouvert en attente de l'extraction des bassins (macro phase 3)
	//le mieux est de travailler en 8 bit apres avoir modifié le contraste
	
	selectWindow("ADD.tif");
	run("Morphological Segmentation");
	selectWindow("Morphological Segmentation"); // Activates the window with the title "Morphological Segmentation".
	call("inra.ijpb.plugins.MorphologicalSegmentation.segment", "tolerance=10.0", "calculateDams=true", "connectivity=6");
	
	log_index = -1;
	while (log_index == -1) {
		cont_log = getInfo("log"); //Returns the contents of the Log window, or "" if the Log window is not open.
		wait(2000);
		log_index = cont_log.indexOf("Whole");
	}
	
}

function Phase3() {

	//apres calcul et extraction des bassins, cette phase extrait l'image stack des bassins
	//extration depuis le plugin : MorpholibJ-Morphological Segmentation.
	//in : MorpholibJ-Morphological Segmentation doit etre en attente
	//out : stack des bassins nommée : "ADD-catchment-basins.tif"
	
	selectWindow("Morphological Segmentation");
	call("inra.ijpb.plugins.MorphologicalSegmentation.setDisplayFormat", "Catchment basins");
	call("inra.ijpb.plugins.MorphologicalSegmentation.createResultImage");
	selectWindow("Morphological Segmentation");
	close();
}

function Phase4() {

	//Filtrage des cellules en fonction de leur surface,
	//les cellules de moins de 200 pixels sont retirées
	//in: image "ADD-catchment-basins" 32 bits issue de macro phase 3
	//out : image "bassin-filtered" 16 bits et rableau des coordonnée des centroïdes des cellules et leur volume

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
	close("\\Others"); // ferme tout sauf bassin-filtered.tif

	run("Analyze Regions 3D", "volume centroid surface_area_method=[Crofton (13 dirs.)] euler_connectivity=6");
	Table.rename("bassin-filtered-morpho", "Results_1.csv"); // Renames a table.
	Table.showRowNumbers(true);
	Table.renameColumn("Centroid.X", "X_Centroid"); // Renames a column.
	Table.renameColumn("Centroid.Y", "Y_Centroid"); // Renames a column.
	Table.renameColumn("Centroid.Z", "Z_Centroid"); // Renames a column.
	//Table.renameColumn("Label", "Cell_Value"); // Renames a column. marche pas pour aucune raison
}

function Phase5() {

	//prominence p can be change in  function of image quality
	//Macro qui execute un find Maxima pour toutes les images d'un stack
	//Il s'agit de l'ancienne macro :"Finddaxima-dilateOnStack.ijm "
	//in: ouvrir l'image acquise sur canal 561 nm qui contient, outre les contours, mais les dots a repérer.
	//out : image stack des dots nommée: "Stack" en binaire

	selectWindow("561.tif");
	// selectWindow(tif_561); // pour le programme final
	p = 30;
	getDimensions(width, height, channels, slices, frames); // Returns the dimensions of the current image.
	setSlice((floor(slices/2))); // Affiche la nième tranche/slices de la pile active (celle du milieu ici).
	run("Enhance Contrast", "saturated=0.35"); // améliorer le contraste local d'une image
	run("8-bit");
	run("Gaussian Blur...", "sigma=2 stack"); // réduit le bruit
	
	n = nSlices; // Returns the number of images in the current stack.
	name = getTitle();
	for(i = 1; i <= n; i++) {
		selectWindow(name);
		setSlice(i); // Affiche la iième tranche de la pile active.
		run("Find Maxima...", "prominence="+p+" output=[Single Points]");
		}
	//Make stack from image named with "Maxima"
	run("Images to Stack", "method=[Copy (center)] name=Stack.tif title=Maxima use"); // Images to Stack
	run("Options...", "iterations=1 count=1 black do=Dilate stack");
	selectWindow("561.tif");
	close();
}

function Phase6() {

	//utilise la methode 3D object counter de Fabrice Cordelière 
	//this macro will find all centroid in 3D, and display a Results tab with they coordonnates
	//in: image named "Stack.tif" of dilated maximas get from phase 5
	//out: Results tab with maximas coordonates
	
	selectWindow("Stack.tif");
	rename("origine");
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	run("3D Objects Counter", "threshold=128 slice=48 min.=3 max.=64995840 centroids");
	selectWindow("Centroids map of origine");
	setThreshold(1, 65534); // Définit les niveaux de seuil inférieur et supérieur.
	setOption("BlackBackground", true); // Active/désactive l'option "Fond noir".
	run("Convert to Mask", "method=Default background=Dark black");
	run("Set Measurements...", "centroid stack redirect=None decimal=3");
	run("Analyze Particles...", "pixel display clear stack"); // le tabeau Results aces les coordonée des spots (en pixel)
	selectWindow("bassin-filtered.tif");
	close("\\Others");
}

function Phase7() {

	//Scan Results tab and add a column with the Cell label for each X,Y position
	//in  : image stack "bassin-filtered" : stack of cell in gray level labeled and size filtered (from phase 4)
	//		"Results" tab with X,Y coordonates and Slice position
	//out : index of Cell number and count of spots in each Cell label
	
	selectWindow("bassin-filtered.tif");
	for (row = 0; row < nResults; row++) {
		x = floor(getResult("X", row));
		y = floor(getResult("Y", row));
		setSlice(floor(getResult("Slice", row)));
		setResult("CellNumber", row, getPixel(x, y));
	}
	
	//This part count for each cell the number of dots included
	SpotInCellsCount = newArray(nResults);
	n = SpotInCellsCount.length;
	Array.fill(SpotInCellsCount,0); // initialisation du tableau à 0 (pour les 665 lignes)
	
	for (row = 0; row < n; row++) { // compte le nombre de point/CellNumber
		a = getResult("CellNumber", row);
		SpotInCellsCount[a]++;
	}
	indexOfCell = Array.getSequence(n);
	Array.show("Nombre de Spot / cellule",indexOfCell,SpotInCellsCount);
	Table.rename("Results", "Results_2.csv");
	close("*");
	// if macro erreur fenètre ouverte --> afficher un message qui explique l'erreur (c'est dû aux mauvais résultats)
}

function Mesure_intensite() {

	// mettre la description de la fonction
	//in  :
	//out :

	open(tif_561); // reouvre l'image original sans la filtre apliquer a la phase 5
	selectWindow("Results_2.csv");
	nombre_ligne = Table.size;
	run("Add...", "value=1 stack"); // on ajoute +1 à toutes les valleurs de pixel pour éviter d'en avoir un noir. 
	
	for (row = 0; row < nombre_ligne; row++) {
		
		selectWindow("Results_2.csv");
		// prend les valeurs  dans les colonne X, Y et Z (Slice) à la ligne row
		x = Table.get("X", row);
		y = Table.get("Y", row);
		z = Table.get("Slice", row);
		Spot_in_cell = Table.get("CellNumber", row);
		
		if (Spot_in_cell != 0){ // Si les coordonnées du spot sont dans une cellule

			// selectWindow(tif_561); // pour le programme final
			selectWindow("561.tif");
			setSlice(z);
			valeur_pixel_cible = getValue(x, y);
			
			if (valeur_pixel_cible != 0){ // si ≠ de 0 --> on à pas encore compté ce spot
				// faire -11 sur les x et y pour le centrer
				makeOval(x-11, y-11, 20, 20); // crée un cercle autour de chaque spot (prend en entrée des pixels)
				getHistogram(0, counts, 65536);
				getThreshold(lower, upper);
				setAutoThreshold();
				run("Set Measurements...", "mean integrated limit redirect=None decimal=3");
				run("Measure");
				Valeur_intensite = getResult("Mean", Table.getSelectionEnd); //Table.getSelectionEnd - Returns the index of the last selected row in the current table, or -1 if there is no selection. 
				selectWindow("Results_2.csv");
				Table.set("Intensity", row, Valeur_intensite); // rajoute la valeur intensité au tableau
				setForegroundColor(0, 0, 0); 
				run("Fill", "slice"); // marque le spot mesurer en noir (0,0,0)
			}
			
			if (valeur_pixel_cible == 0) { // si = de 0 --> on à déjà compté ce spot
				selectWindow("Results_2.csv");
				Table.set("Intensity", row, NaN);
			}
		}

		if (Spot_in_cell == 0) {
			selectWindow("Results_2.csv");
			Table.set("Intensity", row, NaN);
		}
	}
	close();
	close("Results");
	selectWindow("Results_2.csv");
	Table.renameColumn("X", "X_Cluster"); // Renames a column.
	Table.renameColumn("Y", "Y_Cluster"); // Renames a column.
	Table.renameColumn("Slice", "Z_Cluster"); // Renames a column.
}

function Concatenation_Resultat() {

	// mettre la description de la fonction
	//in  :
	//out :
	
	selectWindow("Results_2.csv");
	nb_ligne_2 = Table.size;
	
	// création des listes
	SpotInCellsCount 	= newArray(nb_ligne_2); //créer une array pour chaque colonne, extrait les données de table results dans chaque array
	Cell_Value 			= newArray(nb_ligne_2);
	Intensity			= newArray(nb_ligne_2);
	X_Cluster 			= newArray(nb_ligne_2);
	Y_Cluster 			= newArray(nb_ligne_2);
	Z_Cluster 			= newArray(nb_ligne_2);
	
	Table.sort("CellNumber"); //trie de table results pour pouvoir obtenir les sommes cumulées dans SpotInCellsCount
	
	for (row = 0; row < nb_ligne_2 ; row++) {
		Cell_Value[row] = Table.get("CellNumber", row); //extraction des numéros des cellules dans array CellValue
		Intensity[row] = Table.get("Intensity", row);
		X_Cluster[row] = Table.get("X_Cluster", row); //coordonnée x, y et z des spots
		Y_Cluster[row] = Table.get("Y_Cluster", row); 
		Z_Cluster[row] = Table.get("Z_Cluster", row);
	
	
	
		if(Cell_Value[row] == 0) { // les spot dans la cellule de valeur 0 ne sont pas utilisés (à modifier peut etre)
			SpotInCellsCount[row] = "NaN";
		}
		////////// optimiser ca avec des listes
		/*
		if(SpotInCellsCount[row] != "NaN") { //comptage des spot contenus dans chaque cellule, le comptage final se trouve dans la derniere ligne avec la valeur CellValue d'origine(à améliorer)
			selectWindow("Nombre de Spot / cellule");
			j = Table.get("SpotInCellsCount", Cell_Value[row]);
			selectWindow("Results_2.csv");
			SpotInCellsCount[row] = j;
		}
		*/
	}
	// pour compter le nombre de cellules qui n'ont pas de cluster
	selectWindow("Results_1.csv");
	Table.sort("Label");
	nb_ligne_1 = Table.size;
	Label 		= newArray(nb_ligne_1);
	// création des listes temporaire pour accélérer le calcul et ne pas lire dans les tableaux
	Volumet 	= newArray(nb_ligne_1);
	X_Centroidt = newArray(nb_ligne_1);
	Y_Centroidt = newArray(nb_ligne_1);
	Z_Centroidt = newArray(nb_ligne_1);
	
	for (row = 0; row < nb_ligne_1 ; row++) {
		Label[row] 			= Table.get("Label", row);
		Volumet[row]		= Table.get("Volume", row); //créer une array pour chaque colonne, extrait les données de table results dans chaque array
		X_Centroidt[row]	= Table.get("X_Centroid", row);
		Y_Centroidt[row]	= Table.get("Y_Centroid", row);
		Z_Centroidt[row]	= Table.get("Z_Centroid", row);
	}
	
	nb_diff = 0;
	diff = 0;
	count = 0;
	for (row = 0; row < nb_ligne_1 ; row++) {
		l = Label[row];
		for (row1 = 0; row1 < nb_ligne_2 ; row1++) {
			k = Cell_Value[row1];
			if (k != l) {
				diff = 1;
			}
			if (k == l) {
				count = 1;
			}
		}
		if (diff != count) {
			cellule_sans_cluster += 1;
		}
		diff = 0;
		count = 0;
	}
	//Array.show("rien du tout c'est de la merde",Label,Volumet,Cell_Value);// juste pour voir sur quoi tu travail
	/////////////////// debut concaténation du tableau 1


	Volume 		= newArray(nb_ligne_2);
	X_Centroid 	= newArray(nb_ligne_2);
	Y_Centroid 	= newArray(nb_ligne_2);
	Z_Centroid 	= newArray(nb_ligne_2);
	compteur = cellule_sans_cluster + nb_ligne_2 
	
	l = Label[0];
	j_en_ai_mare = 0
	for (row = 0; row < compteur ; row++) {
		k = Cell_Value[row];
		if (k == 0) { // si on est pas dans une cellule
			Volume[row]		= "NaN";
			X_Centroid[row]	= "NaN";
			Y_Centroid[row]	= "NaN";
			Z_Centroid[row]	= "NaN";
		}
	Array.show("rien du tout c'est de la merde2",X_Centroid,Y_Centroid,Z_Centroid,Volume,Cell_Value);

		if (k != 0) { // si on est dans une cellule
			if (k == l) { // k=l ou k≠l
				l = Label[j_en_ai_mare+1];
				Volume[row]		= Volumet[j_en_ai_mare];
				X_Centroid[row]	= X_Centroidt[j_en_ai_mare];
				Y_Centroid[row]	= Y_Centroidt[j_en_ai_mare];
				Z_Centroid[row]	= Z_Centroidt[j_en_ai_mare];
				j_en_ai_mare += 1;
			}
			
			if (k != l) {
				l = Label[j_en_ai_mare+1];
				Volume[row]		= Volumet[j_en_ai_mare];
				X_Centroid[row]	= X_Centroidt[j_en_ai_mare];
				Y_Centroid[row]	= Y_Centroidt[j_en_ai_mare];
				Z_Centroid[row]	= Z_Centroidt[j_en_ai_mare];
				j_en_ai_mare += 1;
				
			}
		}
	}








	
	Array.show("Results_Finished_2",Volume,X_Centroid,Y_Centroid,Z_Centroid);
	Array.show("Results_Finished_1.csv",Cell_Value,X_Cluster,Y_Cluster,Z_Cluster,Intensity,SpotInCellsCount);

selectWindow("Results_Finished_1.csv");
nombre_ligne_1 = Table.size;
for (row = 0; row < nombre_ligne_1 ; row++) {
	selectWindow("Results_1.csv");
	l = Table.get("Label", row);
	for (row_1 = 0; row_1 < nombre_ligne_1 ; row_1++) {
		selectWindow("Results_Finished_1.csv");
		k = Table.get("Cell_Value", row_1);
			if (k !=0 && k 
			count = 
	}

}




// Table.deleteRows(firstIndex, lastIndex) - Supprime les lignes spécifiées.
// pour supprimer les ligne ou les spots ne sont pas dans les cellules ? poser la question a Julie.




Table.renameColumn("CellValue", "Cell_Value"); // Renames a column.
Table.rename("Results_1.csv", "bassin-filtered-morpho"); // Renames a table.
Table.setColumn(columnName, array); // Assigns an array to the specified column.
}




function Poissons_zebre(){
	Phase1();	
	Phase2();
	Phase3();	
	Phase4();
	Phase5();
	Phase6();
	Phase7();
	Mesure_intensite();
	Concatenation_Resultat();
}