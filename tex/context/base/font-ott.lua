if not modules then modules = { } end modules ['font-ott'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (tables)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
 -- dataonly  = true,
}

local type, next, tonumber, tostring, rawget, rawset = type, next, tonumber, tostring, rawget, rawset
local gsub, lower, format, match = string.gsub, string.lower, string.format, string.match
local is_boolean = string.is_boolean

local setmetatableindex    = table.setmetatableindex
local setmetatablenewindex = table.setmetatablenewindex
local allocate             = utilities.storage.allocate

local fonts                = fonts
local otf                  = fonts.handlers.otf
local otffeatures          = otf.features
local registerotffeature   = otffeatures.register

local tables               = otf.tables or { }
otf.tables                 = tables

local statistics           = otf.statistics or { }
otf.statistics             = statistics

local scripts = allocate {
    ['arab'] = 'arabic',
    ['armn'] = 'armenian',
    ['bali'] = 'balinese',
    ['beng'] = 'bengali',
    ['bopo'] = 'bopomofo',
    ['brai'] = 'braille',
    ['bugi'] = 'buginese',
    ['buhd'] = 'buhid',
    ['byzm'] = 'byzantine music',
    ['cans'] = 'canadian syllabics',
    ['cher'] = 'cherokee',
    ['copt'] = 'coptic',
    ['cprt'] = 'cypriot syllabary',
    ['cyrl'] = 'cyrillic',
    ['deva'] = 'devanagari',
    ['dev2'] = 'devanagari variant 2',
    ['dsrt'] = 'deseret',
    ['ethi'] = 'ethiopic',
    ['geor'] = 'georgian',
    ['glag'] = 'glagolitic',
    ['goth'] = 'gothic',
    ['grek'] = 'greek',
    ['gujr'] = 'gujarati',
    ['guru'] = 'gurmukhi',
    ['hang'] = 'hangul',
    ['hani'] = 'cjk ideographic',
    ['hano'] = 'hanunoo',
    ['hebr'] = 'hebrew',
    ['ital'] = 'old italic',
    ['jamo'] = 'hangul jamo',
    ['java'] = 'javanese',
    ['kana'] = 'hiragana and katakana',
    ['khar'] = 'kharosthi',
    ['khmr'] = 'khmer',
    ['knda'] = 'kannada',
    ['lao' ] = 'lao',
    ['latn'] = 'latin',
    ['limb'] = 'limbu',
    ['linb'] = 'linear b',
    ['math'] = 'mathematical alphanumeric symbols',
    ['mlym'] = 'malayalam',
    ['mlm2'] = 'malayalam variant 2',
    ['mong'] = 'mongolian',
    ['musc'] = 'musical symbols',
    ['mymr'] = 'myanmar',
    ['nko' ] = "n'ko",
    ['ogam'] = 'ogham',
    ['orya'] = 'oriya',
    ['osma'] = 'osmanya',
    ['phag'] = 'phags-pa',
    ['phnx'] = 'phoenician',
    ['runr'] = 'runic',
    ['shaw'] = 'shavian',
    ['sinh'] = 'sinhala',
    ['sylo'] = 'syloti nagri',
    ['syrc'] = 'syriac',
    ['tagb'] = 'tagbanwa',
    ['tale'] = 'tai le',
    ['talu'] = 'tai lu',
    ['taml'] = 'tamil',
    ['telu'] = 'telugu',
    ['tfng'] = 'tifinagh',
    ['tglg'] = 'tagalog',
    ['thaa'] = 'thaana',
    ['thai'] = 'thai',
    ['tibt'] = 'tibetan',
    ['ugar'] = 'ugaritic cuneiform',
    ['xpeo'] = 'old persian cuneiform',
    ['xsux'] = 'sumero-akkadian cuneiform',
    ['yi'  ] = 'yi',
}

local languages = allocate {
    ['aba'] = 'abaza',
    ['abk'] = 'abkhazian',
    ['ady'] = 'adyghe',
    ['afk'] = 'afrikaans',
    ['afr'] = 'afar',
    ['agw'] = 'agaw',
    ['als'] = 'alsatian',
    ['alt'] = 'altai',
    ['amh'] = 'amharic',
    ['ara'] = 'arabic',
    ['ari'] = 'aari',
    ['ark'] = 'arakanese',
    ['asm'] = 'assamese',
    ['ath'] = 'athapaskan',
    ['avr'] = 'avar',
    ['awa'] = 'awadhi',
    ['aym'] = 'aymara',
    ['aze'] = 'azeri',
    ['bad'] = 'badaga',
    ['bag'] = 'baghelkhandi',
    ['bal'] = 'balkar',
    ['bau'] = 'baule',
    ['bbr'] = 'berber',
    ['bch'] = 'bench',
    ['bcr'] = 'bible cree',
    ['bel'] = 'belarussian',
    ['bem'] = 'bemba',
    ['ben'] = 'bengali',
    ['bgr'] = 'bulgarian',
    ['bhi'] = 'bhili',
    ['bho'] = 'bhojpuri',
    ['bik'] = 'bikol',
    ['bil'] = 'bilen',
    ['bkf'] = 'blackfoot',
    ['bli'] = 'balochi',
    ['bln'] = 'balante',
    ['blt'] = 'balti',
    ['bmb'] = 'bambara',
    ['bml'] = 'bamileke',
    ['bos'] = 'bosnian',
    ['bre'] = 'breton',
    ['brh'] = 'brahui',
    ['bri'] = 'braj bhasha',
    ['brm'] = 'burmese',
    ['bsh'] = 'bashkir',
    ['bti'] = 'beti',
    ['cat'] = 'catalan',
    ['ceb'] = 'cebuano',
    ['che'] = 'chechen',
    ['chg'] = 'chaha gurage',
    ['chh'] = 'chattisgarhi',
    ['chi'] = 'chichewa',
    ['chk'] = 'chukchi',
    ['chp'] = 'chipewyan',
    ['chr'] = 'cherokee',
    ['chu'] = 'chuvash',
    ['cmr'] = 'comorian',
    ['cop'] = 'coptic',
    ['cos'] = 'corsican',
    ['cre'] = 'cree',
    ['crr'] = 'carrier',
    ['crt'] = 'crimean tatar',
    ['csl'] = 'church slavonic',
    ['csy'] = 'czech',
    ['dan'] = 'danish',
    ['dar'] = 'dargwa',
    ['dcr'] = 'woods cree',
    ['deu'] = 'german',
    ['dgr'] = 'dogri',
    ['div'] = 'divehi',
    ['djr'] = 'djerma',
    ['dng'] = 'dangme',
    ['dnk'] = 'dinka',
    ['dri'] = 'dari',
    ['dun'] = 'dungan',
    ['dzn'] = 'dzongkha',
    ['ebi'] = 'ebira',
    ['ecr'] = 'eastern cree',
    ['edo'] = 'edo',
    ['efi'] = 'efik',
    ['ell'] = 'greek',
    ['eng'] = 'english',
    ['erz'] = 'erzya',
    ['esp'] = 'spanish',
    ['eti'] = 'estonian',
    ['euq'] = 'basque',
    ['evk'] = 'evenki',
    ['evn'] = 'even',
    ['ewe'] = 'ewe',
    ['fan'] = 'french antillean',
    ['far'] = 'farsi',
    ['fin'] = 'finnish',
    ['fji'] = 'fijian',
    ['fle'] = 'flemish',
    ['fne'] = 'forest nenets',
    ['fon'] = 'fon',
    ['fos'] = 'faroese',
    ['fra'] = 'french',
    ['fri'] = 'frisian',
    ['frl'] = 'friulian',
    ['fta'] = 'futa',
    ['ful'] = 'fulani',
    ['gad'] = 'ga',
    ['gae'] = 'gaelic',
    ['gag'] = 'gagauz',
    ['gal'] = 'galician',
    ['gar'] = 'garshuni',
    ['gaw'] = 'garhwali',
    ['gez'] = "ge'ez",
    ['gil'] = 'gilyak',
    ['gmz'] = 'gumuz',
    ['gon'] = 'gondi',
    ['grn'] = 'greenlandic',
    ['gro'] = 'garo',
    ['gua'] = 'guarani',
    ['guj'] = 'gujarati',
    ['hai'] = 'haitian',
    ['hal'] = 'halam',
    ['har'] = 'harauti',
    ['hau'] = 'hausa',
    ['haw'] = 'hawaiin',
    ['hbn'] = 'hammer-banna',
    ['hil'] = 'hiligaynon',
    ['hin'] = 'hindi',
    ['hma'] = 'high mari',
    ['hnd'] = 'hindko',
    ['ho']  = 'ho',
    ['hri'] = 'harari',
    ['hrv'] = 'croatian',
    ['hun'] = 'hungarian',
    ['hye'] = 'armenian',
    ['ibo'] = 'igbo',
    ['ijo'] = 'ijo',
    ['ilo'] = 'ilokano',
    ['ind'] = 'indonesian',
    ['ing'] = 'ingush',
    ['inu'] = 'inuktitut',
    ['iri'] = 'irish',
    ['irt'] = 'irish traditional',
    ['isl'] = 'icelandic',
    ['ism'] = 'inari sami',
    ['ita'] = 'italian',
    ['iwr'] = 'hebrew',
    ['jan'] = 'japanese',
    ['jav'] = 'javanese',
    ['jii'] = 'yiddish',
    ['jud'] = 'judezmo',
    ['jul'] = 'jula',
    ['kab'] = 'kabardian',
    ['kac'] = 'kachchi',
    ['kal'] = 'kalenjin',
    ['kan'] = 'kannada',
    ['kar'] = 'karachay',
    ['kat'] = 'georgian',
    ['kaz'] = 'kazakh',
    ['keb'] = 'kebena',
    ['kge'] = 'khutsuri georgian',
    ['kha'] = 'khakass',
    ['khk'] = 'khanty-kazim',
    ['khm'] = 'khmer',
    ['khs'] = 'khanty-shurishkar',
    ['khv'] = 'khanty-vakhi',
    ['khw'] = 'khowar',
    ['kik'] = 'kikuyu',
    ['kir'] = 'kirghiz',
    ['kis'] = 'kisii',
    ['kkn'] = 'kokni',
    ['klm'] = 'kalmyk',
    ['kmb'] = 'kamba',
    ['kmn'] = 'kumaoni',
    ['kmo'] = 'komo',
    ['kms'] = 'komso',
    ['knr'] = 'kanuri',
    ['kod'] = 'kodagu',
    ['koh'] = 'korean old hangul',
    ['kok'] = 'konkani',
    ['kon'] = 'kikongo',
    ['kop'] = 'komi-permyak',
    ['kor'] = 'korean',
    ['koz'] = 'komi-zyrian',
    ['kpl'] = 'kpelle',
    ['kri'] = 'krio',
    ['krk'] = 'karakalpak',
    ['krl'] = 'karelian',
    ['krm'] = 'karaim',
    ['krn'] = 'karen',
    ['krt'] = 'koorete',
    ['ksh'] = 'kashmiri',
    ['ksi'] = 'khasi',
    ['ksm'] = 'kildin sami',
    ['kui'] = 'kui',
    ['kul'] = 'kulvi',
    ['kum'] = 'kumyk',
    ['kur'] = 'kurdish',
    ['kuu'] = 'kurukh',
    ['kuy'] = 'kuy',
    ['kyk'] = 'koryak',
    ['lad'] = 'ladin',
    ['lah'] = 'lahuli',
    ['lak'] = 'lak',
    ['lam'] = 'lambani',
    ['lao'] = 'lao',
    ['lat'] = 'latin',
    ['laz'] = 'laz',
    ['lcr'] = 'l-cree',
    ['ldk'] = 'ladakhi',
    ['lez'] = 'lezgi',
    ['lin'] = 'lingala',
    ['lma'] = 'low mari',
    ['lmb'] = 'limbu',
    ['lmw'] = 'lomwe',
    ['lsb'] = 'lower sorbian',
    ['lsm'] = 'lule sami',
    ['lth'] = 'lithuanian',
    ['ltz'] = 'luxembourgish',
    ['lub'] = 'luba',
    ['lug'] = 'luganda',
    ['luh'] = 'luhya',
    ['luo'] = 'luo',
    ['lvi'] = 'latvian',
    ['maj'] = 'majang',
    ['mak'] = 'makua',
    ['mal'] = 'malayalam traditional',
    ['man'] = 'mansi',
    ['map'] = 'mapudungun',
    ['mar'] = 'marathi',
    ['maw'] = 'marwari',
    ['mbn'] = 'mbundu',
    ['mch'] = 'manchu',
    ['mcr'] = 'moose cree',
    ['mde'] = 'mende',
    ['men'] = "me'en",
    ['miz'] = 'mizo',
    ['mkd'] = 'macedonian',
    ['mle'] = 'male',
    ['mlg'] = 'malagasy',
    ['mln'] = 'malinke',
    ['mlr'] = 'malayalam reformed',
    ['mly'] = 'malay',
    ['mnd'] = 'mandinka',
    ['mng'] = 'mongolian',
    ['mni'] = 'manipuri',
    ['mnk'] = 'maninka',
    ['mnx'] = 'manx gaelic',
    ['moh'] = 'mohawk',
    ['mok'] = 'moksha',
    ['mol'] = 'moldavian',
    ['mon'] = 'mon',
    ['mor'] = 'moroccan',
    ['mri'] = 'maori',
    ['mth'] = 'maithili',
    ['mts'] = 'maltese',
    ['mun'] = 'mundari',
    ['nag'] = 'naga-assamese',
    ['nan'] = 'nanai',
    ['nas'] = 'naskapi',
    ['ncr'] = 'n-cree',
    ['ndb'] = 'ndebele',
    ['ndg'] = 'ndonga',
    ['nep'] = 'nepali',
    ['new'] = 'newari',
    ['ngr'] = 'nagari',
    ['nhc'] = 'norway house cree',
    ['nis'] = 'nisi',
    ['niu'] = 'niuean',
    ['nkl'] = 'nkole',
    ['nko'] = "n'ko",
    ['nld'] = 'dutch',
    ['nog'] = 'nogai',
    ['nor'] = 'norwegian',
    ['nsm'] = 'northern sami',
    ['nta'] = 'northern tai',
    ['nto'] = 'esperanto',
    ['nyn'] = 'nynorsk',
    ['oci'] = 'occitan',
    ['ocr'] = 'oji-cree',
    ['ojb'] = 'ojibway',
    ['ori'] = 'oriya',
    ['oro'] = 'oromo',
    ['oss'] = 'ossetian',
    ['paa'] = 'palestinian aramaic',
    ['pal'] = 'pali',
    ['pan'] = 'punjabi',
    ['pap'] = 'palpa',
    ['pas'] = 'pashto',
    ['pgr'] = 'polytonic greek',
    ['pil'] = 'pilipino',
    ['plg'] = 'palaung',
    ['plk'] = 'polish',
    ['pro'] = 'provencal',
    ['ptg'] = 'portuguese',
    ['qin'] = 'chin',
    ['raj'] = 'rajasthani',
    ['rbu'] = 'russian buriat',
    ['rcr'] = 'r-cree',
    ['ria'] = 'riang',
    ['rms'] = 'rhaeto-romanic',
    ['rom'] = 'romanian',
    ['roy'] = 'romany',
    ['rsy'] = 'rusyn',
    ['rua'] = 'ruanda',
    ['rus'] = 'russian',
    ['sad'] = 'sadri',
    ['san'] = 'sanskrit',
    ['sat'] = 'santali',
    ['say'] = 'sayisi',
    ['sek'] = 'sekota',
    ['sel'] = 'selkup',
    ['sgo'] = 'sango',
    ['shn'] = 'shan',
    ['sib'] = 'sibe',
    ['sid'] = 'sidamo',
    ['sig'] = 'silte gurage',
    ['sks'] = 'skolt sami',
    ['sky'] = 'slovak',
    ['sla'] = 'slavey',
    ['slv'] = 'slovenian',
    ['sml'] = 'somali',
    ['smo'] = 'samoan',
    ['sna'] = 'sena',
    ['snd'] = 'sindhi',
    ['snh'] = 'sinhalese',
    ['snk'] = 'soninke',
    ['sog'] = 'sodo gurage',
    ['sot'] = 'sotho',
    ['sqi'] = 'albanian',
    ['srb'] = 'serbian',
    ['srk'] = 'saraiki',
    ['srr'] = 'serer',
    ['ssl'] = 'south slavey',
    ['ssm'] = 'southern sami',
    ['sur'] = 'suri',
    ['sva'] = 'svan',
    ['sve'] = 'swedish',
    ['swa'] = 'swadaya aramaic',
    ['swk'] = 'swahili',
    ['swz'] = 'swazi',
    ['sxt'] = 'sutu',
    ['syr'] = 'syriac',
    ['tab'] = 'tabasaran',
    ['taj'] = 'tajiki',
    ['tam'] = 'tamil',
    ['tat'] = 'tatar',
    ['tcr'] = 'th-cree',
    ['tel'] = 'telugu',
    ['tgn'] = 'tongan',
    ['tgr'] = 'tigre',
    ['tgy'] = 'tigrinya',
    ['tha'] = 'thai',
    ['tht'] = 'tahitian',
    ['tib'] = 'tibetan',
    ['tkm'] = 'turkmen',
    ['tmn'] = 'temne',
    ['tna'] = 'tswana',
    ['tne'] = 'tundra nenets',
    ['tng'] = 'tonga',
    ['tod'] = 'todo',
    ['trk'] = 'turkish',
    ['tsg'] = 'tsonga',
    ['tua'] = 'turoyo aramaic',
    ['tul'] = 'tulu',
    ['tuv'] = 'tuvin',
    ['twi'] = 'twi',
    ['udm'] = 'udmurt',
    ['ukr'] = 'ukrainian',
    ['urd'] = 'urdu',
    ['usb'] = 'upper sorbian',
    ['uyg'] = 'uyghur',
    ['uzb'] = 'uzbek',
    ['ven'] = 'venda',
    ['vit'] = 'vietnamese',
    ['wa' ] = 'wa',
    ['wag'] = 'wagdi',
    ['wcr'] = 'west-cree',
    ['wel'] = 'welsh',
    ['wlf'] = 'wolof',
    ['xbd'] = 'tai lue',
    ['xhs'] = 'xhosa',
    ['yak'] = 'yakut',
    ['yba'] = 'yoruba',
    ['ycr'] = 'y-cree',
    ['yic'] = 'yi classic',
    ['yim'] = 'yi modern',
    ['zhh'] = 'chinese hong kong',
    ['zhp'] = 'chinese phonetic',
    ['zhs'] = 'chinese simplified',
    ['zht'] = 'chinese traditional',
    ['znd'] = 'zande',
    ['zul'] = 'zulu'
}

local features = allocate {
    ['aalt'] = 'access all alternates',
    ['abvf'] = 'above-base forms',
    ['abvm'] = 'above-base mark positioning',
    ['abvs'] = 'above-base substitutions',
    ['afrc'] = 'alternative fractions',
    ['akhn'] = 'akhands',
    ['blwf'] = 'below-base forms',
    ['blwm'] = 'below-base mark positioning',
    ['blws'] = 'below-base substitutions',
    ['c2pc'] = 'petite capitals from capitals',
    ['c2sc'] = 'small capitals from capitals',
    ['calt'] = 'contextual alternates',
    ['case'] = 'case-sensitive forms',
    ['ccmp'] = 'glyph composition/decomposition',
    ['cjct'] = 'conjunct forms',
    ['clig'] = 'contextual ligatures',
    ['cpsp'] = 'capital spacing',
    ['cswh'] = 'contextual swash',
    ['curs'] = 'cursive positioning',
    ['dflt'] = 'default processing',
    ['dist'] = 'distances',
    ['dlig'] = 'discretionary ligatures',
    ['dnom'] = 'denominators',
    ['dtls'] = 'dotless forms', -- math
    ['expt'] = 'expert forms',
    ['falt'] = 'final glyph alternates',
    ['fin2'] = 'terminal forms #2',
    ['fin3'] = 'terminal forms #3',
    ['fina'] = 'terminal forms',
    ['flac'] = 'flattened accents over capitals', -- math
    ['frac'] = 'fractions',
    ['fwid'] = 'full width',
    ['half'] = 'half forms',
    ['haln'] = 'halant forms',
    ['halt'] = 'alternate half width',
    ['hist'] = 'historical forms',
    ['hkna'] = 'horizontal kana alternates',
    ['hlig'] = 'historical ligatures',
    ['hngl'] = 'hangul',
    ['hojo'] = 'hojo kanji forms',
    ['hwid'] = 'half width',
    ['init'] = 'initial forms',
    ['isol'] = 'isolated forms',
    ['ital'] = 'italics',
    ['jalt'] = 'justification alternatives',
    ['jp04'] = 'jis2004 forms',
    ['jp78'] = 'jis78 forms',
    ['jp83'] = 'jis83 forms',
    ['jp90'] = 'jis90 forms',
    ['kern'] = 'kerning',
    ['lfbd'] = 'left bounds',
    ['liga'] = 'standard ligatures',
    ['ljmo'] = 'leading jamo forms',
    ['lnum'] = 'lining figures',
    ['locl'] = 'localized forms',
    ['mark'] = 'mark positioning',
    ['med2'] = 'medial forms #2',
    ['medi'] = 'medial forms',
    ['mgrk'] = 'mathematical greek',
    ['mkmk'] = 'mark to mark positioning',
    ['mset'] = 'mark positioning via substitution',
    ['nalt'] = 'alternate annotation forms',
    ['nlck'] = 'nlc kanji forms',
    ['nukt'] = 'nukta forms',
    ['numr'] = 'numerators',
    ['onum'] = 'old style figures',
    ['opbd'] = 'optical bounds',
    ['ordn'] = 'ordinals',
    ['ornm'] = 'ornaments',
    ['palt'] = 'proportional alternate width',
    ['pcap'] = 'petite capitals',
    ['pnum'] = 'proportional figures',
    ['pref'] = 'pre-base forms',
    ['pres'] = 'pre-base substitutions',
    ['pstf'] = 'post-base forms',
    ['psts'] = 'post-base substitutions',
    ['pwid'] = 'proportional widths',
    ['qwid'] = 'quarter widths',
    ['rand'] = 'randomize',
    ['rkrf'] = 'rakar forms',
    ['rlig'] = 'required ligatures',
    ['rphf'] = 'reph form',
    ['rtbd'] = 'right bounds',
    ['rtla'] = 'right-to-left alternates',
    ['rtlm'] = 'right to left math', -- math
    ['ruby'] = 'ruby notation forms',
    ['salt'] = 'stylistic alternates',
    ['sinf'] = 'scientific inferiors',
    ['size'] = 'optical size',
    ['smcp'] = 'small capitals',
    ['smpl'] = 'simplified forms',
 -- ['ss01'] = 'stylistic set 1',
 -- ['ss02'] = 'stylistic set 2',
 -- ['ss03'] = 'stylistic set 3',
 -- ['ss04'] = 'stylistic set 4',
 -- ['ss05'] = 'stylistic set 5',
 -- ['ss06'] = 'stylistic set 6',
 -- ['ss07'] = 'stylistic set 7',
 -- ['ss08'] = 'stylistic set 8',
 -- ['ss09'] = 'stylistic set 9',
 -- ['ss10'] = 'stylistic set 10',
 -- ['ss11'] = 'stylistic set 11',
 -- ['ss12'] = 'stylistic set 12',
 -- ['ss13'] = 'stylistic set 13',
 -- ['ss14'] = 'stylistic set 14',
 -- ['ss15'] = 'stylistic set 15',
 -- ['ss16'] = 'stylistic set 16',
 -- ['ss17'] = 'stylistic set 17',
 -- ['ss18'] = 'stylistic set 18',
 -- ['ss19'] = 'stylistic set 19',
 -- ['ss20'] = 'stylistic set 20',
    ['ssty'] = 'script style', -- math
    ['subs'] = 'subscript',
    ['sups'] = 'superscript',
    ['swsh'] = 'swash',
    ['titl'] = 'titling',
    ['tjmo'] = 'trailing jamo forms',
    ['tnam'] = 'traditional name forms',
    ['tnum'] = 'tabular figures',
    ['trad'] = 'traditional forms',
    ['twid'] = 'third widths',
    ['unic'] = 'unicase',
    ['valt'] = 'alternate vertical metrics',
    ['vatu'] = 'vattu variants',
    ['vert'] = 'vertical writing',
    ['vhal'] = 'alternate vertical half metrics',
    ['vjmo'] = 'vowel jamo forms',
    ['vkna'] = 'vertical kana alternates',
    ['vkrn'] = 'vertical kerning',
    ['vpal'] = 'proportional alternate vertical metrics',
    ['vrt2'] = 'vertical rotation',
    ['zero'] = 'slashed zero',

    ['trep'] = 'traditional tex replacements',
    ['tlig'] = 'traditional tex ligatures',

    ['ss..'] = 'stylistic set ..',
    ['cv..'] = 'character variant ..',
    ['js..'] = 'justification ..',

    ["dv.."] = "devanagari ..",
    ["ml.."] = "malayalam ..",
}

local baselines = allocate {
    ['hang'] = 'hanging baseline',
    ['icfb'] = 'ideographic character face bottom edge baseline',
    ['icft'] = 'ideographic character face tope edige baseline',
    ['ideo'] = 'ideographic em-box bottom edge baseline',
    ['idtp'] = 'ideographic em-box top edge baseline',
    ['math'] = 'mathmatical centered baseline',
    ['romn'] = 'roman baseline'
}

tables.scripts   = scripts
tables.languages = languages
tables.features  = features
tables.baselines = baselines

local acceptscripts   = true  directives.register("otf.acceptscripts",   function(v) acceptscripts   = v end)
local acceptlanguages = true  directives.register("otf.acceptlanguages", function(v) acceptlanguages = v end)

local report_checks   = logs.reporter("fonts","checks")

-- hm, we overload the metatables

if otffeatures.features then
    for k, v in next, otffeatures.features do
        features[k] = v
    end
    otffeatures.features = features
end

local function swapped(h)
    local r = { }
    for k, v in next, h do
        r[gsub(v,"[^a-z0-9]","")] = k -- is already lower
    end
    return r
end

local verbosescripts   = allocate(swapped(scripts  ))
local verboselanguages = allocate(swapped(languages))
local verbosefeatures  = allocate(swapped(features ))
local verbosebaselines = allocate(swapped(baselines))

-- lets forget about trailing spaces

local function resolve(t,k)
    if k then
        k = gsub(lower(k),"[^a-z0-9]","")
        local v = rawget(t,k)
        if v then
            return v
        end
    end
end

setmetatableindex(verbosescripts,   resolve)
setmetatableindex(verboselanguages, resolve)
setmetatableindex(verbosefeatures,  resolve)
setmetatableindex(verbosebaselines, resolve)

-- We could optimize the next lookups by using an extra metatable and storing
-- already found values but in practice there are not that many lookups so
-- it's never a bottleneck.

setmetatableindex(scripts, function(t,k)
    if k then
        k = lower(k)
        if k == "dflt" then
            return k
        end
        local v = rawget(t,k)
        if v then
            return v
        end
        k = gsub(k," ","")
        v = rawget(t,v)
        if v then
            return v
        elseif acceptscripts then
            report_checks("registering extra script %a",k)
            rawset(t,k,k)
            return k
        end
    end
    return "dflt"
end)

setmetatableindex(languages, function(t,k)
    if k then
        k = lower(k)
        if k == "dflt" then
            return k
        end
        local v = rawget(t,k)
        if v then
            return v
        end
        k = gsub(k," ","")
        v = rawget(t,v)
        if v then
            return v
        elseif acceptlanguages then
            report_checks("registering extra language %a",k)
            rawset(t,k,k)
            return k
        end
    end
    return "dflt"
end)

setmetatablenewindex(languages, "ignore")
setmetatablenewindex(baselines, "ignore")
setmetatablenewindex(baselines, "ignore")

local function resolve(t,k)
    if k then
        k = lower(k)
        local v = rawget(t,k)
        if v then
            return v
        end
        k = gsub(k," ","")
        local v = rawget(t,k)
        if v then
            return v
        end
        local tag, dd = match(k,"(..)(%d+)")
        if tag and dd then
            local v = rawget(t,tag)
            if v then
                return v -- return format(v,tonumber(dd)) -- old way
            else
                local v = rawget(t,tag.."..") -- nicer in overview
                if v then
                    return (gsub(v,"%.%.",tonumber(dd))) -- new way
                end
            end
        end
    end
    return k -- "dflt"
end

setmetatableindex(features, resolve)

local function assign(t,k,v)
    if k and v then
        v = lower(v)
        rawset(t,k,v) -- rawset ?
     -- rawset(features,gsub(v,"[^a-z0-9]",""),k) -- why ? old code
    end
end

setmetatablenewindex(features, assign)

local checkers = {
    rand = function(v)
        return v == true and "random" or v
    end
}

-- Keep this:
--
-- function otf.features.normalize(features)
--     if features then
--         local h = { }
--         for k, v in next, features do
--             k = lower(k)
--             if k == "language" then
--                 v = gsub(lower(v),"[^a-z0-9]","")
--                 h.language = rawget(verboselanguages,v) or (languages[v] and v) or "dflt" -- auto adds
--             elseif k == "script" then
--                 v = gsub(lower(v),"[^a-z0-9]","")
--                 h.script = rawget(verbosescripts,v) or (scripts[v] and v) or "dflt" -- auto adds
--             else
--                 if type(v) == "string" then
--                     local b = is_boolean(v)
--                     if type(b) == "nil" then
--                         v = tonumber(v) or lower(v)
--                     else
--                         v = b
--                     end
--                 end
--                 if not rawget(features,k) then
--                     k = rawget(verbosefeatures,k) or k
--                 end
--                 local c = checkers[k]
--                 h[k] = c and c(v) or v
--             end
--         end
--         return h
--     end
-- end

-- inspect(fonts.handlers.otf.statistics.usedfeatures)

if not storage then
    return
end

local usedfeatures      = statistics.usedfeatures or { }
statistics.usedfeatures = usedfeatures

table.setmetatableindex(usedfeatures, function(t,k) if k then local v = { } t[k] = v return v end end) -- table.autotable

storage.register("fonts/otf/usedfeatures", usedfeatures, "fonts.handlers.otf.statistics.usedfeatures" )

function otf.features.normalize(features)
    if features then
        local h = { }
        for key, value in next, features do
            local k = lower(key)
            if k == "language" then
                local v = gsub(lower(value),"[^a-z0-9]","")
                h.language = rawget(verboselanguages,v) or (languages[v] and v) or "dflt" -- auto adds
            elseif k == "script" then
                local v = gsub(lower(value),"[^a-z0-9]","")
                h.script = rawget(verbosescripts,v) or (scripts[v] and v) or "dflt" -- auto adds
            else
                local uk = usedfeatures[key]
                local uv = uk[value]
                if uv then
                 -- report_checks("feature value %a first seen at %a",value,key)
                else
                    uv = tonumber(value) -- before boolean as there we also handle 0/1
                    if uv then
                        -- we're okay
                    elseif type(value) == "string" then
                        local b = is_boolean(value)
                        if type(b) == "nil" then
                            uv = lower(value)
                        else
                            uv = b
                        end
                    else
                        uv = value
                    end
                    if not rawget(features,k) then
                        k = rawget(verbosefeatures,k) or k
                    end
                    local c = checkers[k]
                    if c then
                        uv = c(uv) or vc
                    end
                    uk[value] = uv
                end
                h[k] = uv
            end
        end
        return h
    end
end

--~ table.print(otf.features.normalize({ language = "dutch", liga = "yes", ss99 = true, aalt = 3, abcd = "yes"  } ))

-- When I feel the need ...

--~ tables.aat = {
--~     [ 0] = {
--~         name = "allTypographicFeaturesType",
--~         [ 0] = "allTypeFeaturesOnSelector",
--~         [ 1] = "allTypeFeaturesOffSelector",
--~     },
--~     [ 1] = {
--~         name = "ligaturesType",
--~         [0 ] = "requiredLigaturesOnSelector",
--~         [1 ] = "requiredLigaturesOffSelector",
--~         [2 ] = "commonLigaturesOnSelector",
--~         [3 ] = "commonLigaturesOffSelector",
--~         [4 ] = "rareLigaturesOnSelector",
--~         [5 ] = "rareLigaturesOffSelector",
--~         [6 ] = "logosOnSelector    ",
--~         [7 ] = "logosOffSelector   ",
--~         [8 ] = "rebusPicturesOnSelector",
--~         [9 ] = "rebusPicturesOffSelector",
--~         [10] = "diphthongLigaturesOnSelector",
--~         [11] = "diphthongLigaturesOffSelector",
--~         [12] = "squaredLigaturesOnSelector",
--~         [13] = "squaredLigaturesOffSelector",
--~         [14] = "abbrevSquaredLigaturesOnSelector",
--~         [15] = "abbrevSquaredLigaturesOffSelector",
--~     },
--~     [ 2] = {
--~         name = "cursiveConnectionType",
--~         [ 0] = "unconnectedSelector",
--~         [ 1] = "partiallyConnectedSelector",
--~         [ 2] = "cursiveSelector    ",
--~     },
--~     [ 3] = {
--~         name = "letterCaseType",
--~         [ 0] = "upperAndLowerCaseSelector",
--~         [ 1] = "allCapsSelector    ",
--~         [ 2] = "allLowerCaseSelector",
--~         [ 3] = "smallCapsSelector  ",
--~         [ 4] = "initialCapsSelector",
--~         [ 5] = "initialCapsAndSmallCapsSelector",
--~     },
--~     [ 4] = {
--~         name = "verticalSubstitutionType",
--~         [ 0] = "substituteVerticalFormsOnSelector",
--~         [ 1] = "substituteVerticalFormsOffSelector",
--~     },
--~     [ 5] = {
--~         name = "linguisticRearrangementType",
--~         [ 0] = "linguisticRearrangementOnSelector",
--~         [ 1] = "linguisticRearrangementOffSelector",
--~     },
--~     [ 6] = {
--~         name = "numberSpacingType",
--~         [ 0] = "monospacedNumbersSelector",
--~         [ 1] = "proportionalNumbersSelector",
--~     },
--~     [ 7] = {
--~         name = "appleReserved1Type",
--~     },
--~     [ 8] = {
--~         name = "smartSwashType",
--~         [ 0] = "wordInitialSwashesOnSelector",
--~         [ 1] = "wordInitialSwashesOffSelector",
--~         [ 2] = "wordFinalSwashesOnSelector",
--~         [ 3] = "wordFinalSwashesOffSelector",
--~         [ 4] = "lineInitialSwashesOnSelector",
--~         [ 5] = "lineInitialSwashesOffSelector",
--~         [ 6] = "lineFinalSwashesOnSelector",
--~         [ 7] = "lineFinalSwashesOffSelector",
--~         [ 8] = "nonFinalSwashesOnSelector",
--~         [ 9] = "nonFinalSwashesOffSelector",
--~     },
--~     [ 9] = {
--~         name = "diacriticsType",
--~         [ 0] = "showDiacriticsSelector",
--~         [ 1] = "hideDiacriticsSelector",
--~         [ 2] = "decomposeDiacriticsSelector",
--~     },
--~     [10] = {
--~         name = "verticalPositionType",
--~         [ 0] = "normalPositionSelector",
--~         [ 1] = "superiorsSelector  ",
--~         [ 2] = "inferiorsSelector  ",
--~         [ 3] = "ordinalsSelector   ",
--~     },
--~     [11] = {
--~         name = "fractionsType",
--~         [ 0] = "noFractionsSelector",
--~         [ 1] = "verticalFractionsSelector",
--~         [ 2] = "diagonalFractionsSelector",
--~     },
--~     [12] = {
--~         name = "appleReserved2Type",
--~     },
--~     [13] = {
--~         name = "overlappingCharactersType",
--~         [ 0] = "preventOverlapOnSelector",
--~         [ 1] = "preventOverlapOffSelector",
--~     },
--~     [14] = {
--~         name = "typographicExtrasType",
--~          [0 ] = "hyphensToEmDashOnSelector",
--~          [1 ] = "hyphensToEmDashOffSelector",
--~          [2 ] = "hyphenToEnDashOnSelector",
--~          [3 ] = "hyphenToEnDashOffSelector",
--~          [4 ] = "unslashedZeroOnSelector",
--~          [5 ] = "unslashedZeroOffSelector",
--~          [6 ] = "formInterrobangOnSelector",
--~          [7 ] = "formInterrobangOffSelector",
--~          [8 ] = "smartQuotesOnSelector",
--~          [9 ] = "smartQuotesOffSelector",
--~          [10] = "periodsToEllipsisOnSelector",
--~          [11] = "periodsToEllipsisOffSelector",
--~     },
--~     [15] = {
--~         name = "mathematicalExtrasType",
--~          [ 0] = "hyphenToMinusOnSelector",
--~          [ 1] = "hyphenToMinusOffSelector",
--~          [ 2] = "asteriskToMultiplyOnSelector",
--~          [ 3] = "asteriskToMultiplyOffSelector",
--~          [ 4] = "slashToDivideOnSelector",
--~          [ 5] = "slashToDivideOffSelector",
--~          [ 6] = "inequalityLigaturesOnSelector",
--~          [ 7] = "inequalityLigaturesOffSelector",
--~          [ 8] = "exponentsOnSelector",
--~          [ 9] = "exponentsOffSelector",
--~     },
--~     [16] = {
--~         name = "ornamentSetsType",
--~         [ 0] = "noOrnamentsSelector",
--~         [ 1] = "dingbatsSelector   ",
--~         [ 2] = "piCharactersSelector",
--~         [ 3] = "fleuronsSelector   ",
--~         [ 4] = "decorativeBordersSelector",
--~         [ 5] = "internationalSymbolsSelector",
--~         [ 6] = "mathSymbolsSelector",
--~     },
--~     [17] = {
--~         name = "characterAlternativesType",
--~         [ 0] = "noAlternatesSelector",
--~     },
--~     [18] = {
--~         name = "designComplexityType",
--~         [ 0] = "designLevel1Selector",
--~         [ 1] = "designLevel2Selector",
--~         [ 2] = "designLevel3Selector",
--~         [ 3] = "designLevel4Selector",
--~         [ 4] = "designLevel5Selector",
--~     },
--~     [19] = {
--~         name = "styleOptionsType",
--~         [ 0] = "noStyleOptionsSelector",
--~         [ 1] = "displayTextSelector",
--~         [ 2] = "engravedTextSelector",
--~         [ 3] = "illuminatedCapsSelector",
--~         [ 4] = "titlingCapsSelector",
--~         [ 5] = "tallCapsSelector   ",
--~     },
--~     [20] = {
--~         name = "characterShapeType",
--~         [0 ] = "traditionalCharactersSelector",
--~         [1 ] = "simplifiedCharactersSelector",
--~         [2 ] = "jis1978CharactersSelector",
--~         [3 ] = "jis1983CharactersSelector",
--~         [4 ] = "jis1990CharactersSelector",
--~         [5 ] = "traditionalAltOneSelector",
--~         [6 ] = "traditionalAltTwoSelector",
--~         [7 ] = "traditionalAltThreeSelector",
--~         [8 ] = "traditionalAltFourSelector",
--~         [9 ] = "traditionalAltFiveSelector",
--~         [10] = "expertCharactersSelector",
--~     },
--~     [21] = {
--~         name = "numberCaseType",
--~         [ 0] = "lowerCaseNumbersSelector",
--~         [ 1] = "upperCaseNumbersSelector",
--~     },
--~     [22] = {
--~         name = "textSpacingType",
--~         [ 0] = "proportionalTextSelector",
--~         [ 1] = "monospacedTextSelector",
--~         [ 2] = "halfWidthTextSelector",
--~         [ 3] = "normallySpacedTextSelector",
--~     },
--~     [23] = {
--~         name = "transliterationType",
--~         [ 0] = "noTransliterationSelector",
--~         [ 1] = "hanjaToHangulSelector",
--~         [ 2] = "hiraganaToKatakanaSelector",
--~         [ 3] = "katakanaToHiraganaSelector",
--~         [ 4] = "kanaToRomanizationSelector",
--~         [ 5] = "romanizationToHiraganaSelector",
--~         [ 6] = "romanizationToKatakanaSelector",
--~         [ 7] = "hanjaToHangulAltOneSelector",
--~         [ 8] = "hanjaToHangulAltTwoSelector",
--~         [ 9] = "hanjaToHangulAltThreeSelector",
--~     },
--~     [24] = {
--~         name = "annotationType",
--~         [ 0] = "noAnnotationSelector",
--~         [ 1] = "boxAnnotationSelector",
--~         [ 2] = "roundedBoxAnnotationSelector",
--~         [ 3] = "circleAnnotationSelector",
--~         [ 4] = "invertedCircleAnnotationSelector",
--~         [ 5] = "parenthesisAnnotationSelector",
--~         [ 6] = "periodAnnotationSelector",
--~         [ 7] = "romanNumeralAnnotationSelector",
--~         [ 8] = "diamondAnnotationSelector",
--~     },
--~     [25] = {
--~         name = "kanaSpacingType",
--~         [ 0] = "fullWidthKanaSelector",
--~         [ 1] = "proportionalKanaSelector",
--~     },
--~     [26] = {
--~         name = "ideographicSpacingType",
--~         [ 0] = "fullWidthIdeographsSelector",
--~         [ 1] = "proportionalIdeographsSelector",
--~     },
--~     [103] = {
--~         name = "cjkRomanSpacingType",
--~         [ 0] = "halfWidthCJKRomanSelector",
--~         [ 1] = "proportionalCJKRomanSelector",
--~         [ 2] = "defaultCJKRomanSelector",
--~         [ 3] = "fullWidthCJKRomanSelector",
--~     },
--~ }
