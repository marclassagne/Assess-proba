%include('header_init.tpl', heading='Assess probabilities')
<h3 id="attribute_name"></h3>

<div id="select">
	<table class="table">
		<thead>
			<tr>
				<th>Attribute</th>
				<th>Type</th>
				<th>Method</th>				
				<th>Assess another point</th>
				<th>Reset assessements</th>
			</tr>
		</thead>
		<tbody id="table_attributes">
		</tbody>
	</table>
</div>

<div id="trees"></div>

<div id="charts">
	<h2>Select the regression function you want to use</h2>
</div>

<div id="main_graph" class="col-lg-5"></div>
<div id="functions" class="col-lg-7"></div>

%include('header_end.tpl')
%include('js.tpl')

<script>
	var tree_image = '{{ get_url("static", path="img/tree_choice.png") }}';
</script>

<!-- Tree object -->
<script src="{{ get_url('static', path='js/tree.js') }}"></script>

<script>
	$(function() {
		$('li.questions').addClass("active");
		$('#attribute_name').hide()
		$('#charts').hide();
		$('#main_graph').hide();
		$('#functions').hide();

		var assess_session = JSON.parse(localStorage.getItem("assess_session")),
			settings = assess_session.settings;

		// We fill the table of the existing attributes and assessments
		for (var i = 0; i < assess_session.attributes.length; i++) {
			if (!assess_session.attributes[i].checked) //if this attribute is not activated
				continue; //we skip this attribute and go to the next one
				
			var attribute = assess_session.attributes[i],
				text_table = '<tr><td>' + attribute.name + '</td>'+
							 '<td>' + attribute.type + '</td>'+
							 '<td>' + attribute.method + '</td>';
							
			text_table += '<td><table style="width:100%"></td>';
			
			if (attribute.method == "GM" || attribute.method == "LE"){
				text_table += '<tr><td>Probabilité évaluée</td><td>: </td>';

				if(attribute.questionnaire.points[attribute.val_med[0]]){
					text_table += '<td>' + attribute.questionnaire.points[attribute.val_med[0]] + '</td></table></td>';
				} else {
					text_table += '<td><button type="button" class="btn btn-default btn-xs answer_quest_'+(attribute.type=="Qualitative"?"quali":"quanti")+'" id="q_' + attribute.name + '_' + attribute.val_med[0] + '_' + 0 + '">Assess</button>' + '</td></tr></table></td>';
				};
			} else {
				for (var key in attribute.questionnaire.points){
					text_table += '<tr><td>' + key + '</td><td> : </td>'+
								  '<td>' + attribute.questionnaire.points[key] + '</td></tr>';
				};
				
				for (var ii=Object.keys(attribute.questionnaire.points).length; ii<3; ii++){
					text_table += '<tr><td>-</td><td> : </td>'+
								  '<td><button type="button" class="btn btn-default btn-xs answer_quest_'+(attribute.type=="Qualitative"?"quali":"quanti")+'" id="q_' + attribute.name + '_' + ii + '_' + ii + '">Assess</button>' + '</td></tr>';
				};
			}; 
			

			
			text_table += '<td><button type="button" id="deleteK' + i + '" class="btn btn-default btn-xs">Reset</button></td>';

			$('#table_attributes').append(text_table);

			(function(_i) {
				$('#deleteK' + _i).click(function() {
					if (confirm("Are you sure you want to delete all the assessments for "+assess_session.attributes[_i].name+"?") == false) {
							return
					};
					assess_session.attributes[_i].questionnaire = {
							'number': 0,
							'points': {},
							'utility': {}
					};
					// backup local
					localStorage.setItem("assess_session", JSON.stringify(assess_session));
					//refresh the page
					window.location.reload();
				});
			})(i);
		}


		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		///////////////////////////////////////////////////////////////// CLICK ON THE ANSWER BUTTON ////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		/// When you click on a QUANTITATIVE attribute for assessment
		$('.answer_quest_quanti').click(function() {
			// we store the name, value, and index of the attribute
			var question_id = $(this).attr('id').slice(2).split('_'),
				question_name = question_id[0],
				question_val = question_id[1],
				question_index = question_id[2];
			console.log(question_id);
				
			// we delete the slect div
			$('#select').hide();
			$('#attribute_name').show().html(question_name.toUpperCase());


			// which index is it ?
			var indice;
			for (var j = 0; j < assess_session.attributes.length; j++) {
				if (assess_session.attributes[j].name == question_name) {
					indice = j;
				}
			}

			var val_min = assess_session.attributes[indice].val_min,
				val_max = assess_session.attributes[indice].val_max,
				unit = assess_session.attributes[indice].unit,
				method = assess_session.attributes[indice].method,
				mode = assess_session.attributes[indice].mode;

			function random_proba(proba1, proba2) {
				var coin = Math.round(Math.random());
				if (coin == 1) {
					return proba1;
				} else {
					return proba2;
				}
			}


			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////// GM METHOD ////////////////////////////////////////////////////////////////
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			if (method == 'GM') {
				(function() {
					// VARIABLES
					var probability = 0.3;
					var min_interval = 0;
					var max_interval = 1;

					// INTERFACE

					var arbre_le = new Arbre('gauche', '#trees', settings.display, "LE_left");
					var arbre_droite = new Arbre('droite', '#trees', settings.display, "LE_right");

					// SETUP ARBRE GAUCHE
					arbre_le.questions_proba_haut = probability;
					arbre_le.questions_val_max = 'Voyage';
					arbre_le.questions_val_min = 'Restau';
					arbre_le.display();
					arbre_le.update();

					// SETUP ARBRE DROIT
					arbre_droite.questions_proba_haut = 'Occurence';

					// The certain gain will change whether it is the 1st, 2nd or 3rd questionnaire
					arbre_droite.questions_val_max = 'Voyage';
					arbre_droite.questions_val_min = 'Restaurant';
					arbre_droite.display();
					arbre_droite.update();

					// we add the choice button
					$('#trees').append('<div class=choice style="text-align: center;"><p>Which option do you prefer?</p><button type="button" class="btn btn-default lottery_a">Lottery A</button><button type="button" class="btn btn-default lottery_b">Lottery B</button></div>')


					function treat_answer(data) {
						min_interval = data.interval[0];
						max_interval = data.interval[1];
						probability = parseFloat(data.proba).toFixed(2);

						if (max_interval - min_interval <= 0.05) {
							arbre_le.questions_proba_haut = probability;
							arbre_le.update();
							ask_final_value(Math.round((max_interval + min_interval) * 100 / 2) / 100);
						} else {
							arbre_le.questions_proba_haut = probability;
							arbre_le.update();
						}
					}

					function ask_final_value(val) {
						$('.choice').hide();
						$('.container-fluid').append(
							'<div id= "final_value" style="text-align: center;"><br /><br /><p>We are almost done. Please enter the probability that makes you indifferent between the two situations above. Your previous choices indicate that it should be between ' + min_interval + ' and ' + max_interval + ' but you are not constrained to that range <br /> ' + min_interval +
							'\
						 <= <input type="text" class="form-control" id="final_proba" placeholder="Probability" value="' + val + '" style="width: 100px; display: inline-block"> <= ' + max_interval +
							'</p><button type="button" class="btn btn-default final_validation">Validate</button></div>'
						);

						// when the user validate
						$('.final_validation').click(function() {
							var final_proba = parseFloat($('#final_proba').val());

							if (final_proba <= 1 && final_proba >= 0) {
								// we save it
								assess_session.attributes[indice].questionnaire.points[question_val] = final_proba;
								assess_session.attributes[indice].questionnaire.number += 1;
								// backup local
								localStorage.setItem("assess_session", JSON.stringify(assess_session));
								// we reload the page
								window.location.reload();
							}
						});
					}



					// HANDLE USERS ACTIONS
					$('.lottery_a').click(function() {
						$.post('ajax', '{"type":"question", "method": "LE", "proba": ' + String(probability) + ', "min_interval": ' + min_interval + ', "max_interval": ' + max_interval + ' ,"choice": "0" , "mode": "' + String(mode) + '"}', function(data) {
							treat_answer(data);
							console.log(data);
						});
					});

					$('.lottery_b').click(function() {
						$.post('ajax', '{"type":"question","method": "LE", "proba": ' + String(probability) + ', "min_interval": ' + min_interval + ', "max_interval": ' + max_interval + ' ,"choice": "1" , "mode": "' + String(mode) + '"}', function(data) {
							treat_answer(data);
							console.log(data);
						});
					});
				})()
			}


		});

		/// When you click on a QUALITATIVE attribute for assessment
		$('.answer_quest_quali').click(function() {
			// we store the name of the attribute
			var question_id = $(this).attr('id').slice(2).split('_'),
				question_name = question_id[0],
				question_val = question_id[1],
				question_index = question_id[2];
			
			// we delete the select div
			$('#select').hide();
			$('#attribute_name').show().html(question_name.toUpperCase());


			// which index is it ? / which attribute is it ?
			var indice;
			for (var j = 0; j < assess_session.attributes.length; j++) {
				if (assess_session.attributes[j].name == question_name) {
					indice = j;
				}
			}

			var val_min = assess_session.attributes[indice].val_min,
				val_max = assess_session.attributes[indice].val_max,
				method = assess_session.attributes[indice].method;

		
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////// PE METHOD ////////////////////////////////////////////////////////////////
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			if (method == 'PE') {
				(function() {
					// VARIABLES
					var probability = 0.75,
						min_interval = 0,
						max_interval = 1;

					// INTERFACE
					var arbre_pe = new Arbre('pe', '#trees', settings.display, "PE");
					

					// The certain gain is the clicked med_value					
					arbre_pe.questions_val_mean = question_val;
					
					// SETUP ARBRE GAUCHE
					arbre_pe.questions_proba_haut = probability;
					
					arbre_pe.questions_val_max = val_max;
					arbre_pe.questions_val_min = val_min;
					
					arbre_pe.display();
					arbre_pe.update();

					$('#trees').append('</div><div class=choice style="text-align: center;">'+
										'<p>Which option do you prefer?</p>'+
										'<button type="button" class="btn btn-default" id="gain"> Certain gain </button>'+
										'<button type="button" class="btn btn-default" id="lottery"> Lottery </button></div>');

					// FUNCTIONS
					function sync_values() {
						arbre_pe.questions_proba_haut = probability;
						arbre_pe.update();
					}

					function treat_answer(data) {
						min_interval = data.interval[0];
						max_interval = data.interval[1];
						probability = parseFloat(data.proba).toFixed(2);

						if (max_interval - min_interval <= 0.05) {
							sync_values();
							ask_final_value(Math.round((max_interval + min_interval) * 100 / 2) / 100);
						} else {
							sync_values();
						}
					}

					function ask_final_value(val) {
						// we delete the choice div
						$('.choice').hide();
						$('.container-fluid').append(
							'<div id= "final_value" style="text-align: center;"><br /><br />'+
							'<p>We are almost done. Please enter the probability that makes you indifferent between the two situations above. Your previous choices indicate that it should be between ' + min_interval + ' and ' + max_interval + ' but you are not constrained to that range <br /> ' + min_interval +
							'\
							<= <input type="text" class="form-control" id="final_proba" placeholder="Probability" value="' + val + '" style="width: 100px; display: inline-block"> <= ' + max_interval +
							'</p><button type="button" class="btn btn-default final_validation">Validate</button></div>'
						);


						// when the user validate
						$('.final_validation').click(function() {
							var final_proba = parseFloat($('#final_proba').val());

							if (final_proba <= 1 && final_proba >= 0) {
								// we save it
								assess_session.attributes[indice].questionnaire.points[question_val]=final_proba;
								assess_session.attributes[indice].questionnaire.number += 1;
								
								localStorage.setItem("assess_session", JSON.stringify(assess_session)); // backup local
								window.location.reload(); // we reload the page
							}
						});
					}

					sync_values();

					// HANDLE USERS ACTIONS
					$('#gain').click(function() {
						$.post('ajax', 
							'{"type":"question",'+
							'"method": "PE",'+
							'"proba": ' + String(probability) + ','+
							'"min_interval": ' + min_interval + ','+
							'"max_interval": ' + max_interval + ','+
							'"choice": "0",'+
							'"mode": "normal"}',
							function(data) {
								treat_answer(data);
								console.log("PE 2");
							});
					});

					$('#lottery').click(function() {
						$.post('ajax', 
							'{"type":"question",'+
							'"method": "PE",'+
							'"proba": ' + String(probability) + ','+
							'"min_interval": ' + min_interval + ','+
							'"max_interval": ' + max_interval + ','+
							'"choice": "1",'+
							'"mode": "normal"}',
							function(data) {
								treat_answer(data);
								console.log("PE 2");
							});
					});
				})()
			}
		});


	
		
		/// When you click on a QUALITATIVE utility function button
		$('.calc_util_quali').click(function() {
			// we store the name of the attribute
			var utility_name = $(this).attr('id').slice(2);
			
			// we delete the select div
			$('#select').hide();
			//$('#attribute_name').show().html(question_name.toUpperCase());

			// which index is it ?
			var indice;
			for (var j = 0; j < assess_session.attributes.length; j++) {
				if (assess_session.attributes[j].name == utility_name) {
					indice = j;
				}
			}

			var val_min = assess_session.attributes[indice].val_min,
				val_max = assess_session.attributes[indice].val_max,
				val_med = assess_session.attributes[indice].val_med,
				list_names = [].concat(val_min, val_med, val_max),
				points = assess_session.attributes[indice].questionnaire.points,
				list_points = [];

			points[val_min] = 0; //On force l'utilité de la pire à 0
			points[val_max] = 1; //On force l'utilité de la meilleure à 1
			
			for (var ii=0, len=list_names.length; ii<len; ii++) {
				list_points.push(points[list_names[ii]]);
			};
			
			function addGraph(data_graph, names_graph) {
				$.post('ajax', 
					JSON.stringify({
						"type": "svg_QUALI",
						"data": data_graph,
						"list_names": names_graph,
						"width": 6
					}), 
				function(data2) {
					$('#main_graph').append(data2);
				});
			}
			
			$('#main_graph').show().empty();
			addGraph(list_points, list_names);
			
		});
		

	
	});
</script>
<!-- Library to copy into clipboard -->
<script src="{{ get_url('static', path='js/clipboard.min.js') }}"></script>
</body>

</html>
