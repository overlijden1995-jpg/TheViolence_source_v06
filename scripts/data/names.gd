extends RefCounted
## Name bank for every unit. Each culture has curated first names and surnames plus a
## surname generator (roots and endings), so the bank runs to hundreds of thousands of
## distinct full names. Gangs draw about four in five members from their own culture and
## the rest from related ones; police and paramedics draw from every culture.
## Everything here is data: swap a gang's culture in GANG_CULTURES.

const CULTURES := {
	"irish": {
		"m": ["Sean", "Patrick", "Liam", "Connor", "Declan", "Brendan", "Cian", "Eoin", "Ciaran", "Kieran",
			"Padraig", "Seamus", "Finn", "Ronan", "Cormac", "Darragh", "Niall", "Colm", "Fergal", "Donal",
			"Aidan", "Kevin", "Brian", "Dermot", "Shane", "Michael", "Thomas", "John", "James", "Francis",
			"Desmond", "Malachy", "Owen", "Rory", "Tadhg", "Killian", "Oisin", "Diarmuid", "Eamon", "Lorcan",
			"Conall", "Barry", "Gerard", "Terence", "Cathal", "Dara", "Fionn", "Mick", "Paddy", "Danny",
			"Jimmy", "Frankie", "Tommy", "Bobby", "Joe", "Kieron", "Ultan", "Senan", "Fintan", "Ruairi"],
		"f": ["Siobhan", "Aoife", "Niamh", "Ciara", "Saoirse", "Roisin", "Orla", "Maeve", "Grainne", "Sinead",
			"Brigid", "Deirdre", "Eileen", "Fiona", "Kathleen", "Maureen", "Nora", "Una", "Clodagh", "Aisling", "Caoimhe"],
		"s": ["Murphy", "Kelly", "Walsh", "Byrne", "Ryan", "Doyle", "Kennedy", "Lynch", "Murray", "Quinn",
			"Moore", "Daly", "Brennan", "Burke", "Collins", "Gallagher", "Doherty", "Duffy", "Flynn", "Healy",
			"Hayes", "Keane", "Kavanagh", "Nolan", "Power", "Regan", "Sheehan", "Tierney", "Whelan", "Fitzgerald",
			"Fitzpatrick", "Costello", "Delaney", "Donovan", "Egan", "Farrell", "Hogan", "Moran", "Brady", "Carroll",
			"Cullen", "Dunne", "Foley", "Hennessy", "Kearney", "Lennon", "Maguire", "Mulligan", "Noonan", "Phelan",
			"Scanlon", "Sweeney", "Tobin", "Coughlan", "Devlin", "Flanagan", "Geraghty", "Heffernan", "Kinsella", "Hanrahan"],
		"gen": [{"pre": ["O'"], "roots": ["Brien", "Connor", "Sullivan", "Neill", "Donnell", "Reilly", "Malley", "Shea",
				"Hara", "Rourke", "Keefe", "Leary", "Toole", "Grady", "Dwyer", "Callaghan", "Mahony", "Driscoll",
				"Halloran", "Dowd", "Flaherty", "Gorman", "Loughlin", "Mara", "Riordan", "Boyle", "Kane", "Byrne"], "suf": [""]},
			{"pre": ["Mc", "Mac"], "roots": ["Carthy", "Mahon", "Namara", "Grath", "Donagh", "Cormack", "Kenna",
				"Laughlin", "Gowan", "Garry", "Hugh", "Nally", "Manus", "Bride", "Cabe", "Cann", "Govern",
				"Kiernan", "Guire", "Elroy", "Ateer", "Closkey", "Dermott", "Evoy", "Fadden", "Gee", "Ginley",
				"Keown", "Kenzie", "Loughney", "Nulty", "Phee", "Sharry", "Sweeney", "Teague"], "suf": [""]}],
	},
	"italian": {
		"m": ["Antonio", "Giuseppe", "Giovanni", "Salvatore", "Vincenzo", "Francesco", "Carmine", "Luigi", "Mario", "Angelo",
			"Domenico", "Pasquale", "Rocco", "Sal", "Vito", "Carlo", "Enzo", "Gennaro", "Luca", "Marco",
			"Matteo", "Paolo", "Pietro", "Raffaele", "Sergio", "Stefano", "Tommaso", "Aldo", "Bruno", "Dante",
			"Fabio", "Gino", "Lorenzo", "Massimo", "Nico", "Orlando", "Renato", "Silvio", "Ugo", "Vittorio",
			"Alessandro", "Cosimo", "Filippo", "Gaetano", "Nunzio", "Rosario", "Tony", "Joey", "Frankie", "Sonny",
			"Carmelo", "Corrado", "Emilio", "Fausto", "Benito", "Calogero", "Ciro", "Michele", "Ottavio", "Santo"],
		"f": ["Maria", "Giulia", "Francesca", "Rosa", "Lucia", "Angela", "Teresa", "Carmela", "Sofia", "Chiara",
			"Elena", "Gianna", "Valentina", "Alessandra", "Concetta", "Antonella", "Paola", "Serena", "Isabella", "Graziella"],
		"s": ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco",
			"Bruno", "Gallo", "Conti", "De Luca", "Mancini", "Costa", "Giordano", "Rizzo", "Lombardi", "Moretti",
			"Barbieri", "Fontana", "Santoro", "Mariani", "Rinaldi", "Caruso", "Ferrara", "Galli", "Martini", "Leone",
			"Longo", "Gentile", "Martinelli", "Vitale", "Lombardo", "Serra", "Coppola", "De Santis", "D'Angelo", "Marchetti",
			"Parisi", "Villa", "Conte", "Ferraro", "Ferri", "Fabbri", "Bianco", "Marini", "Grasso", "Valentini",
			"Messina", "Sala", "De Angelis", "Gatti", "Pellegrini", "Palumbo", "Sanna", "Farina", "Rizzi", "Monti",
			"Cattaneo", "Morelli", "Amato", "Silvestri", "Mazza", "Testa", "Grassi", "Pellegrino", "Carbone", "Giuliani",
			"Benedetti", "Barone", "Rossetti", "Caputo", "Montanari", "Guerra", "Palmieri", "Bernardi", "Martino", "Fiore",
			"LaRocca", "LoBianco", "DiMarco", "DiNapoli", "Corvino", "Abruzzo", "Calabrese", "Napolitano", "Siciliano", "Pugliese"],
		"gen": [{"pre": [""], "roots": ["Ross", "Bianc", "Ferr", "Gall", "Marin", "Ricc", "Mancin", "Morell", "Bellin",
				"Cappell", "Ciccar", "Donat", "Gambin", "Marchett", "Orland", "Pirozz", "Salern", "Tomas", "Vacc",
				"Benedett", "Carbon", "Fasan", "Gargan", "Lanz", "Mastr", "Nard", "Pagan", "Pasqual", "Ruggier",
				"Sorrent", "Spinell", "Tagliafer", "Vent", "Zamp", "Abbat", "Bonfigl", "Caval", "Fabbr", "Iannucc", "Mattarazz"],
				"suf": ["i", "o", "ini", "elli", "etti", "ucci", "ano", "one", "esi", "acci", "otti", "ello", "ella", "ino"]},
			{"pre": ["De", "Di", "La", "Lo"], "roots": ["Luca", "Santis", "Angelis", "Marco", "Napoli", "Rocca", "Bianco",
				"Maggio", "Stefano", "Pietro", "Paola", "Giacomo", "Russo", "Vito", "Carlo", "Palma", "Fazio", "Cicco",
				"Mauro", "Nardo", "Pace", "Sanzo", "Torre", "Vecchio"], "suf": [""]}],
	},
	"latin": {
		"m": ["José", "Juan", "Luis", "Carlos", "Jorge", "Miguel", "Alejandro", "Pedro", "Manuel", "Francisco",
			"Javier", "Ricardo", "Fernando", "Eduardo", "Roberto", "Rafael", "Héctor", "Raúl", "Sergio", "Andrés",
			"Diego", "Mateo", "Santiago", "Emilio", "Ramón", "Arturo", "Alberto", "Ernesto", "Hugo", "Ignacio",
			"Julio", "Marco", "Mario", "Óscar", "Pablo", "Rubén", "Salvador", "Tomás", "Víctor", "Joaquín",
			"Gerardo", "Esteban", "Cristian", "Edgar", "Iván", "Jesús", "Armando", "Gustavo", "Rodrigo", "Leonel",
			"Wilfredo", "Nelson", "Orlando", "Efraín", "Ángel", "Brayan", "Kevin", "Yahir", "Erick", "Moisés"],
		"f": ["María", "Ana", "Carmen", "Lucía", "Isabel", "Sofía", "Valentina", "Gabriela", "Daniela", "Mariana",
			"Paola", "Adriana", "Rosa", "Elena", "Patricia", "Alejandra", "Ximena", "Camila", "Yesenia", "Marisol", "Lorena"],
		"s": ["García", "Rodríguez", "Martínez", "Hernández", "López", "González", "Pérez", "Sánchez", "Ramírez", "Torres",
			"Flores", "Rivera", "Gómez", "Díaz", "Morales", "Reyes", "Cruz", "Ortiz", "Gutiérrez", "Chávez",
			"Ramos", "Ruiz", "Álvarez", "Mendoza", "Castillo", "Jiménez", "Moreno", "Romero", "Herrera", "Medina",
			"Aguilar", "Vargas", "Castro", "Guerrero", "Rojas", "Delgado", "Navarro", "Salazar", "Cortés", "Campos",
			"Vega", "Soto", "Ríos", "Luna", "Molina", "Espinoza", "Cabrera", "Fuentes", "Acosta", "Paredes",
			"Montoya", "Cárdenas", "Zamora", "Valdez", "Ochoa", "Peña", "Santiago", "Quintero", "Barrera", "Bautista",
			"Calderón", "Contreras", "Durán", "Figueroa", "Galindo", "Lozano", "Maldonado", "Orozco", "Pacheco", "Rosales",
			"Serrano", "Trujillo", "Villanueva", "Zúñiga", "Ibarra", "Miranda", "Robles", "Sandoval", "Solís", "Tapia"],
		"gen": [{"pre": [""], "roots": ["Rodrígu", "Martín", "Hernánd", "Lóp", "Gonzál", "Pér", "Sánch", "Ramír",
				"Fernánd", "Góm", "Álvar", "Jimén", "Vásqu", "Domíngu", "Gutiérr", "Ménd", "Núñ", "Benít",
				"Suár", "Velázqu", "Márqu", "Ibáñ", "Estév", "Enríqu", "Benavid", "Ordóñ", "Téll", "Yáñ",
				"Cháv", "Muñ"], "suf": ["ez"]},
			{"pre": ["Villa", "Monte", "Torre", "Campo", "Valle", "Casa"], "roots": ["nueva", "verde", "alta", "real",
				"negro", "alegre", "mayor", "blanca", "hermosa", "lobos", "franca", "grande"], "suf": [""]}],
		"double": 0.15,
	},
	"slavic": {
		"m": ["Aleksandr", "Dmitri", "Sergei", "Nikolai", "Ivan", "Mikhail", "Andrei", "Viktor", "Yuri", "Oleg",
			"Pavel", "Vladimir", "Alexei", "Boris", "Igor", "Konstantin", "Leonid", "Maksim", "Roman", "Stanislav",
			"Vadim", "Valentin", "Vasily", "Yevgeny", "Anatoly", "Arkady", "Bogdan", "Taras", "Mykola", "Petro",
			"Ostap", "Tomasz", "Piotr", "Krzysztof", "Marek", "Pawel", "Jakub", "Janusz", "Wojciech", "Dragan",
			"Milan", "Goran", "Zoran", "Nenad", "Miroslav", "Radovan", "Stefan", "Vuk", "Dejan", "Branko",
			"Lev", "Gennady", "Ruslan", "Artyom", "Timur", "Kirill", "Danylo", "Lukasz", "Bartosz", "Nemanja"],
		"f": ["Natalia", "Olga", "Tatiana", "Svetlana", "Irina", "Elena", "Anastasia", "Ekaterina", "Marina", "Yulia",
			"Oksana", "Daria", "Agnieszka", "Katarzyna", "Magdalena", "Jelena", "Milica", "Vesna", "Halyna", "Larisa"],
		"s": ["Ivanov", "Petrov", "Sidorov", "Smirnov", "Volkov", "Sokolov", "Orlov", "Belov", "Kozlov", "Popov",
			"Lebedev", "Vasilyev", "Morozov", "Novikov", "Fedorov", "Mikhailov", "Egorov", "Pavlov", "Semyonov", "Golubev",
			"Vinogradov", "Bogdanov", "Vorobyov", "Zaitsev", "Solovyov", "Borisov", "Yakovlev", "Grigoryev", "Romanov", "Kuznetsov",
			"Medvedev", "Nikitin", "Zakharov", "Tarasov", "Belyaev", "Komarov", "Kiselyov", "Makarov", "Andreev", "Kovalyov",
			"Kovalenko", "Bondarenko", "Tkachenko", "Kravchenko", "Shevchenko", "Boyko", "Melnyk", "Kovalchuk", "Polishchuk", "Savchuk",
			"Marchenko", "Lysenko", "Rudenko", "Moroz", "Tkachuk", "Kowalski", "Nowak", "Wiśniewski", "Wójcik", "Kamiński",
			"Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski", "Kozłowski", "Jankowski", "Mazur", "Kwiatkowski", "Krawczyk",
			"Piotrowski", "Grabowski", "Pawlak", "Michalski", "Jovanović", "Petrović", "Nikolić", "Marković", "Stojanović", "Ilić",
			"Stanković", "Pavlović", "Popović", "Živković", "Tomić", "Kostić", "Lukić", "Vuković", "Zarya", "Gromov"],
		"gen": [{"pre": [""], "roots": ["Abram", "Agafon", "Aksen", "Anis", "Arkhip", "Bazhen", "Bobr", "Byk", "Chern",
				"Davyd", "Demid", "Fom", "Gord", "Grach", "Karas", "Kazak", "Klim", "Korol", "Kryl", "Lap",
				"Luk", "Masl", "Miron", "Naum", "Panfil", "Pankrat", "Ryab", "Saf", "Shil", "Sobol",
				"Sych", "Vlas", "Yerm", "Zhur", "Gorb", "Kotl", "Kuzm", "Sukh", "Tikhon", "Rog"], "suf": ["ov", "ov", "in"]},
			{"pre": [""], "roots": ["Koval", "Bondar", "Tkach", "Kravch", "Shevch", "Moroz", "Panch", "Hryts", "Lyts",
				"Kost", "Zakharch", "Fedorch", "Dmytr", "Prokop", "Ivash", "Petr", "Marty", "Yarem", "Lev", "Hnat"], "suf": ["enko", "uk"]},
			{"pre": [""], "roots": ["Kowal", "Wiśniew", "Lewandow", "Zieliń", "Dąbrow", "Kozłow", "Jankow", "Grabow", "Piotrow",
				"Michal", "Sadow", "Wróblew", "Pawłow", "Zawad", "Borkow", "Czarnow", "Malinow", "Sikor", "Wilczyń", "Ostrow"], "suf": ["ski"]},
			{"pre": [""], "roots": ["Jovan", "Petr", "Mark", "Stojan", "Stank", "Pavl", "Pop", "Tom", "Kost", "Luk", "Vuk",
				"Mil", "Rad", "Đur", "Rist", "Simon", "Zor", "Bog", "Drag", "Vasil"], "suf": ["ović", "ić"]}],
	},
	"anglo": {
		"m": ["James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph", "Charles", "Thomas",
			"Christopher", "Daniel", "Matthew", "Andrew", "Joshua", "Ryan", "Jacob", "Tyler", "Brandon", "Justin",
			"Nathan", "Adam", "Kyle", "Scott", "Eric", "Jeffrey", "Mark", "Paul", "Steven", "Travis",
			"Dustin", "Cody", "Wade", "Clay", "Hank", "Grant", "Mitchell", "Spencer", "Garrett", "Colin"],
		"f": ["Jennifer", "Sarah", "Jessica", "Ashley", "Emily", "Megan", "Rachel", "Lauren", "Amanda", "Katherine",
			"Elizabeth", "Hannah", "Rebecca", "Allison", "Brooke", "Courtney", "Heather", "Lindsay", "Molly", "Abigail"],
		"s": ["Smith", "Johnson", "Williams", "Brown", "Miller", "Davis", "Wilson", "Anderson", "Taylor", "Thomas",
			"Moore", "Martin", "Thompson", "White", "Harris", "Clark", "Lewis", "Robinson", "Walker", "Young",
			"Allen", "King", "Wright", "Scott", "Green", "Baker", "Adams", "Nelson", "Hill", "Campbell",
			"Mitchell", "Roberts", "Carter", "Phillips", "Evans", "Turner", "Parker", "Collins", "Edwards", "Stewart",
			"Morris", "Rogers", "Reed", "Cook", "Morgan", "Bell", "Cooper", "Richardson", "Cox", "Howard",
			"Ward", "Peterson", "Gray", "Watson", "Brooks", "Bennett", "Wood", "Barnes", "Ross", "Henderson",
			"Coleman", "Jenkins", "Perry", "Powell", "Long", "Patterson", "Hughes", "Butler", "Simmons", "Foster",
			"Bryant", "Alexander", "Russell", "Griffin", "Hayes", "Myers", "Ford", "Hamilton", "Graham", "Sullivan"],
		"gen": [{"pre": [""], "roots": ["Ash", "Black", "Brad", "Brook", "Cald", "Crom", "Dun", "Fair", "Hart", "Holl",
				"Kings", "Lang", "Marsh", "Mid", "North", "Pres", "Ride", "Shel", "Stan", "Thorn", "Wake", "West", "Whit", "Wolf"],
				"suf": ["ford", "well", "ton", "ley", "wood", "field", "bridge", "worth", "more", "by"]}],
	},
	"black_american": {
		"m": ["Marcus", "Darnell", "Terrence", "Andre", "Jamal", "Malik", "DeShawn", "Tyrone", "Jerome", "Reginald",
			"Cedric", "Darius", "Isaiah", "Elijah", "Xavier", "Damon", "Lamar", "Curtis", "Calvin", "Otis",
			"Rashad", "Trevon", "Jalen", "Kendrick", "Desmond", "Byron", "Clarence", "Maurice", "Roderick", "Vernon"],
		"f": ["Keisha", "Tamika", "Latoya", "Monique", "Ebony", "Aaliyah", "Imani", "Jasmine", "Danielle", "Shanice",
			"Tiana", "Kiara", "Simone", "Crystal", "Brianna", "Destiny", "Nia", "Alicia", "Yolanda", "Gwendolyn"],
		"s": ["Washington", "Jefferson", "Jackson", "Johnson", "Williams", "Brown", "Jones", "Davis", "Robinson", "Harris",
			"Thomas", "Moore", "Taylor", "Walker", "Jenkins", "Banks", "Booker", "Freeman", "Gaines", "Holloway",
			"Mosley", "Pettaway", "Simmons", "Tolliver", "Whitfield", "Coleman", "Dawkins", "Grier", "Hairston", "Lattimore",
			"Mayfield", "Odom", "Pickens", "Ruffin", "Spearman", "Toussaint", "Vance", "Wilkerson", "Battle", "Lyles"],
		"gen": [],
	},
	"caribbean": {
		"m": ["Winston", "Delroy", "Errol", "Fitzroy", "Leroy", "Desmond", "Clive", "Junior", "Neville", "Rohan",
			"Jean", "Pierre", "Jean-Baptiste", "Ricardo", "Dwayne", "Kemar", "Shane", "Omar", "Ricky", "Andrew"],
		"f": ["Marcia", "Claudette", "Sharon", "Paulette", "Simone", "Natalie", "Nadine", "Kerry-Ann", "Judith", "Fabienne"],
		"s": ["Campbell", "Brown", "Thompson", "Grant", "McKenzie", "Reid", "Gordon", "Morgan", "Francis", "Blackwood",
			"Pierre", "Joseph", "Jean-Louis", "Charles", "Baptiste", "Dupont", "Celestin", "Toussaint", "Ferdinand", "St. Fleur",
			"Rodney", "Dacosta", "Henry", "Bailey", "Clarke", "Ellis", "Facey", "Gayle", "Lindo", "Barrett"],
		"gen": [],
	},
	"chinese": {
		"m": ["Wei", "Jun", "Hao", "Lei", "Jian", "Ming", "Chen", "Bo", "Tao", "Yong", "Kevin", "Jason", "Eric", "Andy", "Vincent"],
		"f": ["Mei", "Lin", "Xiu", "Hui", "Yan", "Jing", "Li", "Fang", "Grace", "Vivian", "Michelle", "Cindy"],
		"s": ["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou", "Xu", "Sun", "Ma", "Zhu",
			"Hu", "Guo", "He", "Lin", "Luo", "Gao", "Cheung", "Wong", "Chan", "Leung", "Lau", "Ng", "Tang", "Yip", "Kwan", "Fung"],
		"gen": [],
	},
	"korean": {
		"m": ["Min-jun", "Seo-jun", "Ji-hoon", "Hyun-woo", "Dong-hyun", "Sung-min", "Jae-won", "Tae-yang", "Daniel", "Steven"],
		"f": ["Seo-yeon", "Ji-woo", "Min-seo", "Ha-eun", "Soo-ah", "Yuna", "Jiyoung", "Grace", "Esther", "Hannah"],
		"s": ["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim", "Han", "Oh", "Seo", "Shin", "Kwon", "Hwang"],
		"gen": [],
	},
	"vietnamese": {
		"m": ["Minh", "Tuan", "Duc", "Hung", "Long", "Quang", "Thanh", "Huy", "Khoa", "Bao"],
		"f": ["Linh", "Thao", "Trang", "Huong", "Ngoc", "Mai", "Phuong", "Anh", "Lan", "Vy"],
		"s": ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Huynh", "Phan", "Vu", "Vo", "Dang", "Bui", "Do", "Ho", "Ngo", "Duong", "Ly"],
		"gen": [],
	},
	"filipino": {
		"m": ["Jose", "Mark", "Rodel", "Arnel", "Jomar", "Rommel", "Noel", "Paolo", "Carlo", "Benjie"],
		"f": ["Maricel", "Jocelyn", "Rowena", "Analyn", "Kristine", "Joy", "Liza", "Rhea", "Ma. Theresa", "Divina"],
		"s": ["Santos", "Reyes", "Cruz", "Bautista", "Ocampo", "Garcia", "Mendoza", "Torres", "Tomas", "Andrada",
			"Castillo", "Flores", "Villanueva", "Ramos", "Dizon", "Aquino", "Manalo", "Pascual", "Dela Cruz", "Macaraeg"],
		"gen": [],
	},
	"south_asian": {
		"m": ["Arjun", "Rohan", "Vikram", "Rahul", "Amit", "Sanjay", "Imran", "Faisal", "Harpreet", "Gurpreet",
			"Ravi", "Anil", "Kiran", "Nikhil", "Suresh", "Tariq", "Asif", "Bilal", "Jaspal", "Deepak"],
		"f": ["Priya", "Anjali", "Neha", "Pooja", "Aisha", "Fatima", "Simran", "Kavya", "Meera", "Sana", "Nadia", "Divya"],
		"s": ["Patel", "Sharma", "Singh", "Kumar", "Gupta", "Shah", "Mehta", "Reddy", "Iyer", "Nair", "Khan", "Ahmed",
			"Chaudhry", "Malik", "Qureshi", "Siddiqui", "Gill", "Sandhu", "Dhillon", "Grewal", "Joshi", "Rao", "Desai", "Kapoor", "Bose"],
		"gen": [],
	},
	"arab": {
		"m": ["Omar", "Khalid", "Youssef", "Hassan", "Karim", "Tariq", "Sami", "Nabil", "Rami", "Ziad", "Fadi", "Walid", "Adel", "Bassam", "Majid"],
		"f": ["Layla", "Yasmin", "Nour", "Rania", "Huda", "Salma", "Dina", "Hana", "Lina", "Mariam"],
		"s": ["Haddad", "Khoury", "Nasser", "Saleh", "Mansour", "Hamdan", "Aziz", "Farah", "Awad", "Barakat",
			"Darwish", "Hijazi", "Jaber", "Karam", "Najjar", "Qasim", "Rahman", "Sabbagh", "Shami", "Zaher"],
		"gen": [],
	},
	"west_african": {
		"m": ["Chinedu", "Emeka", "Oluwaseun", "Kwame", "Kofi", "Babatunde", "Ifeanyi", "Tunde", "Yaw", "Kojo", "Obinna", "Segun"],
		"f": ["Ngozi", "Adaeze", "Chiamaka", "Abena", "Ama", "Folake", "Funmilayo", "Efua", "Yetunde", "Nneka"],
		"s": ["Okafor", "Adeyemi", "Okonkwo", "Mensah", "Asante", "Owusu", "Boateng", "Adebayo", "Eze", "Nwosu",
			"Ogunleye", "Oyelaran", "Danso", "Appiah", "Nwachukwu", "Bello", "Afolabi", "Ojo", "Achebe", "Obi"],
		"gen": [],
	},
	"greek": {
		"m": ["Nikos", "Giorgos", "Dimitris", "Kostas", "Yannis", "Panos", "Stavros", "Christos", "Vasilis", "Spiros"],
		"f": ["Eleni", "Katerina", "Sofia", "Dimitra", "Georgia", "Ioanna", "Anna", "Despina", "Vasiliki", "Christina"],
		"s": ["Papadopoulos", "Georgiou", "Nikolaidis", "Konstantinou", "Pappas", "Alexopoulos", "Dimitriou", "Karagiannis",
			"Vlachos", "Economou", "Stavropoulos", "Antoniou", "Christodoulou", "Mavros", "Kostopoulos", "Theodorou"],
		"gen": [],
	},
	"portuguese": {
		"m": ["João", "Tiago", "Rui", "Nuno", "Bruno", "Paulo", "Vitor", "Rodrigo", "Gustavo", "Thiago", "Lucas", "Fábio"],
		"f": ["Ana", "Beatriz", "Inês", "Mariana", "Carla", "Juliana", "Fernanda", "Leticia", "Joana", "Raquel"],
		"s": ["Silva", "Santos", "Ferreira", "Pereira", "Oliveira", "Costa", "Rodrigues", "Martins", "Jesus", "Sousa",
			"Fernandes", "Gonçalves", "Gomes", "Lopes", "Marques", "Alves", "Almeida", "Ribeiro", "Pinto", "Carvalho",
			"Teixeira", "Moreira", "Correia", "Mendes", "Nunes", "Soares", "Vieira", "Monteiro", "Cardoso", "Rocha"],
		"gen": [],
	},
	"german": {
		"m": ["Lukas", "Jonas", "Felix", "Tobias", "Florian", "Stefan", "Markus", "Andreas", "Matthias", "Jürgen", "Dieter", "Klaus"],
		"f": ["Anna", "Lena", "Katharina", "Julia", "Sabine", "Petra", "Monika", "Ursula", "Franziska", "Johanna"],
		"s": ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann",
			"Koch", "Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann", "Braun", "Krüger",
			"Hartmann", "Lange", "Werner", "Krause", "Lehmann", "Köhler", "Bauer", "Vogel", "Kaiser", "Fuchs"],
		"gen": [],
	},
	"japanese": {
		"m": ["Hiroshi", "Takeshi", "Kenji", "Daisuke", "Yuki", "Ryota", "Shota", "Kazuki", "Makoto", "Kenta"],
		"f": ["Yuko", "Akiko", "Haruka", "Aya", "Emi", "Naomi", "Sakura", "Mai", "Rina", "Kaori"],
		"s": ["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato",
			"Yoshida", "Yamada", "Sasaki", "Yamaguchi", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Mori"],
		"gen": [],
	},
}

## Police and paramedics: every culture, weighted roughly like a big mixed city.
const DIVERSE := {"anglo": 16, "black_american": 13, "latin": 13, "irish": 7, "italian": 7, "slavic": 6,
	"chinese": 5, "korean": 3, "vietnamese": 3, "filipino": 3, "south_asian": 6, "arab": 4, "west_african": 4,
	"caribbean": 4, "greek": 2, "portuguese": 2, "german": 3, "japanese": 2}

## Each gang: its own culture for about four in five members, related cultures for the rest.
const GANG_CULTURES := [
	{"main": "irish", "also": ["anglo", "irish", "german", "slavic"]},
	{"main": "italian", "also": ["italian", "greek", "anglo", "portuguese"]},
	{"main": "latin", "also": ["latin", "caribbean", "portuguese", "filipino"]},
	{"main": "slavic", "also": ["slavic", "german", "greek", "anglo"]},
]
const GANG_MAIN_SHARE := 0.8

var rng := RandomNumberGenerator.new()
var used := {}


func _init(seed_val := 1) -> void:
	rng.seed = seed_val * 7919 + 13


## A gang member's name (index into GANG_CULTURES).
func gang_name(gi: int, female_share := 0.08) -> String:
	var gc: Dictionary = GANG_CULTURES[gi % GANG_CULTURES.size()]
	var cult: String = gc["main"]
	if rng.randf() >= GANG_MAIN_SHARE:
		var also: Array = gc["also"]
		cult = also[rng.randi() % also.size()]
	return _unique(cult, rng.randf() < female_share)


## An officer's or paramedic's name, from any culture.
func diverse_name(female_share := 0.3) -> String:
	var total := 0
	for k in DIVERSE:
		total += DIVERSE[k]
	var r := rng.randi() % total
	var cult := "anglo"
	for k in DIVERSE:
		r -= DIVERSE[k]
		if r < 0:
			cult = k
			break
	return _unique(cult, rng.randf() < female_share)


func _unique(cult: String, female: bool) -> String:
	var nm := ""
	for attempt in 12:
		nm = full_name(cult, female)
		if not used.has(nm):
			break
	if used.has(nm):
		nm += " " + ["Jr.", "II", "III"][rng.randi() % 3]
	used[nm] = true
	return nm


func full_name(cult: String, female: bool) -> String:
	var c: Dictionary = CULTURES[cult]
	var firsts: Array = c["f"] if female else c["m"]
	var first: String = firsts[rng.randi() % firsts.size()]
	var last := surname(cult, female)
	if c.get("double", 0.0) > 0.0 and rng.randf() < c["double"]:
		last += " " + surname(cult, female)
	return "%s %s" % [first, last]


## A surname: curated most of the time, generated from roots and endings otherwise.
func surname(cult: String, female := false) -> String:
	var c: Dictionary = CULTURES[cult]
	var gens: Array = c["gen"]
	var s := ""
	if gens.is_empty() or rng.randf() < 0.55:
		var lst: Array = c["s"]
		s = lst[rng.randi() % lst.size()]
	else:
		var g: Dictionary = gens[rng.randi() % gens.size()]
		var pre: String = g["pre"][rng.randi() % g["pre"].size()]
		var root: String = g["roots"][rng.randi() % g["roots"].size()]
		var suf: String = g["suf"][rng.randi() % g["suf"].size()]
		if cult == "italian" and root.length() > 2 and root[root.length() - 1] == root[root.length() - 2]:
			suf = ["i", "o"][rng.randi() % 2]
		s = pre + root + suf
	if female and cult == "slavic":
		if s.ends_with("ov") or s.ends_with("ev") or s.ends_with("in"):
			s += "a"
		elif s.ends_with("ski"):
			s = s.substr(0, s.length() - 1) + "a"
	return s


## How many distinct full names the bank can make for a culture (curated and generated
## surnames times first names).
static func capacity(cult: String) -> int:
	var c: Dictionary = CULTURES[cult]
	var surn: int = c["s"].size()
	for g in c["gen"]:
		surn += g["pre"].size() * g["roots"].size() * g["suf"].size()
	return (c["m"].size() + c["f"].size()) * surn
