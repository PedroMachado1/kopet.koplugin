--[[
    KoPet i18n — Internationalization module.

    Detects KOReader's language setting and provides translated strings.
    Base language: English. Falls back to English if no translation found.

    Usage:
        local T = require("kopet_i18n").T
        local msg = T("Feed")  --> "Alimentar" (if language is pt_BR)
]]

local logger = require("logger")

local KoPetI18n = {}

-- ─────────────────────────────────────────────────────────────
-- Detect current language
-- ─────────────────────────────────────────────────────────────
local _lang = nil
local function get_lang()
    if _lang then return _lang end
    local ok, gettext = pcall(require, "gettext")
    if ok and gettext and gettext.current_lang then
        local lang = gettext.current_lang
        if lang and lang ~= "C" then
            _lang = lang
            return _lang
        end
    end
    _lang = "en"
    return _lang
end

-- ─────────────────────────────────────────────────────────────
-- Translation Tables
-- Key = English string, Value = translated string
-- ─────────────────────────────────────────────────────────────
local translations = {

    -- ═════════════════════════════════════════
    -- Portuguese (Brazil)
    -- ═════════════════════════════════════════
    pt_BR = {
        -- Menu
        ["View Pet"] = "Ver Pet",
        ["Care"] = "Cuidados",
        ["Quick Action"] = "Acao Rapida",
        ["Pet Info"] = "Informacoes do Pet",
        ["Settings"] = "Configuracoes",
        ["Danger Zone"] = "Zona de Risco",
        ["Feed"] = "Alimentar",
        ["Pet"] = "Acariciar",
        ["Give Treat"] = "Dar Petisco",
        ["Give Medicine"] = "Dar Remedio",
        ["Journal"] = "Diario de Bordo",
        ["Accessories"] = "Acessorios",
        ["No accessories found yet."] = "Nenhum acessorio encontrado ainda.",
        ["Unequip Accessory"] = "Desequipar Acessorio",
        ["No journal entries yet."] = "O diario esta vazio.",
        ["Statistics"] = "Estatisticas",
        ["Today Summary"] = "Resumo de Hoje",
        ["Care actions: %d"] = "Acoes de cuidado: %d",
        ["Medicine found: %d"] = "Remedios encontrados: %d",
        ["Difficulty: %s"] = "Dificuldade: %s",
        ["Easy (3-7 pgs)"] = "Facil (3-7 pag)",
        ["Normal (10-15 pgs)"] = "Normal (10-15 pag)",
        ["Hard (20-30 pgs)"] = "Dificil (20-30 pag)",
        ["Pages per food: %d"] = "Paginas por racao: %d",
        ["%d pages"] = "%d paginas",
        ["Set to: %d pages per food"] = "Configurado: %d paginas por racao",
        ["Reset Pet"] = "Resetar Pet",
        ["Rename Pet"] = "Renomear Pet",
        ["Reset"] = "Resetar",
        ["Cancel"] = "Cancelar",
        ["Save"] = "Salvar",
        ["Are you sure you want to reset KoPet?\n\nAll progress will be lost!"] = "Tem certeza que deseja resetar o KoPet?\n\nTodo o progresso sera perdido!",
        ["KoPet reset! New pet created."] = "KoPet resetado! Novo pet criado.",
        ["Error: KoPet modules failed to load."] = "Erro: modulos do KoPet nao carregaram.",
        ["Error loading statistics."] = "Erro ao carregar estatisticas.",
        ["Enter a name for your pet:"] = "Digite um nome para seu pet:",

        -- Stats
        ["Level: %d"] = "Nivel: %d",
        ["XP: %d / %d (next level)"] = "XP: %d / %d (proximo nivel)",
        ["Total XP: %d"] = "XP Total: %d",
        ["Hunger: %d%%"] = "Fome: %d%%",
        ["Happiness: %d%%"] = "Felicidade: %d%%",
        ["Energy: %d%%"] = "Energia: %d%%",
        ["Food: %d"] = "Racao: %d",
        ["Treats: %d"] = "Petiscos: %d",
        ["Medicine: %d"] = "Remedio: %d",
        ["Crystals: %d"] = "Cristais: %d",
        ["Accessory: %s"] = "Acessorio: %s",
        ["None"] = "Nenhum",
        ["Pages read: %d"] = "Paginas lidas: %d",
        ["Books completed: %d"] = "Livros completos: %d",
        ["Streak: %d days"] = "Streak: %d dias",
        ["Pet age: %d days"] = "Idade do pet: %d dias",

        -- UI Panel
        ["Deep Sleep..."] = "Sono Profundo...",
        ["Mood: %s"] = "Humor: %s",
        ["Happy"] = "Feliz",
        ["Normal"] = "Normal",
        ["Hungry"] = "Faminto",
        ["Sleeping"] = "Dormindo",
        ["Eating"] = "Comendo",
        ["Hunger"] = "Fome",
        ["Happiness"] = "Felicidade",
        ["Energy"] = "Energia",
        ["Level"] = "Nivel",
        ["Lv.%d"] = "Nv.%d",
        ["Food: %d  |  Treats: %d  |  Crystals: %d"] = "Racao: %d  |  Petiscos: %d  |  Cristais: %d",
        ["Food: %d  |  Treats: %d  |  Medicine: %d  |  Cryst: %d"] = "Racao: %d  |  Petiscos: %d  |  Remedio: %d  |  Crist: %d",
        ["Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d"] = "Paginas: %d  |  Livros: %d  |  Streak: %d d  |  Idade: %d d",
        ["Total XP: %d  |  Next level: %d XP"] = "XP Total: %d  |  Proximo nivel: %d XP",
        ["Feed (%d)"] = "Alimentar (%d)",
        ["Give Treat (%d)"] = "Dar Petisco (%d)",
        ["Close"] = "Fechar",

        -- Events
        ["Level %d!"] = "Nivel %d!",
        ["Food +1! (Total: %d)"] = "Racao +1! (Total: %d)",
        ["Rare Treat! (%d%% of book)"] = "Petisco Raro! (%d%% do livro)",
        ["Streak lost! (%d days)"] = "Streak perdida! (%d dias)",
        ["No food! Read more pages to earn some."] = "Sem racao! Leia mais paginas para ganhar.",
        ["Your pet woke up! (-100 XP)"] = "Seu pet acordou! (-100 XP)",
        ["Fed! Hunger: %d%%"] = "Alimentado! Fome: %d%%",
        ["No treats! Reach milestones in books."] = "Sem petiscos! Atinja marcos nos livros.",
        ["Your pet is sick and cannot eat. Needs Medicine!"] = "Seu pet esta doente e nao pode comer. Precisa de remedio!",
        ["No medicine! Keep reading while sick to find some."] = "Sem remedio! Continue lendo enquanto ele estiver doente.",
        ["Cured! Your pet is healthy again."] = "Curado! Seu pet esta saudavel novamente.",
        ["Your pet is healthy! No need for medicine."] = "Seu pet esta saudavel. Nao precisa de remedio.",
        ["Found Medicine!"] = "Remedio encontrado!",
        ["Your pet became sick from starvation!"] = "Seu pet ficou doente por ficar muito tempo sem comer!",
        ["Your pet is sick..."] = "Seu pet esta doente...",
        ["Your pet looks bored. Give it some attention."] = "Seu pet parece entediado. Dê um pouco de atencao.",
        ["Your pet is sleepy. Let it rest a bit."] = "Seu pet esta sonolento. Deixe-o descansar um pouco.",
        ["Your pet feels rested again."] = "Seu pet se sente descansado novamente.",
        ["Found accessory: %s"] = "Acessorio encontrado: %s",
        ["Treat given! Hunger: %d%% | Happiness: %d%%"] = "Petisco dado! Fome: %d%% | Felicidade: %d%%",
        ["Your pet is in deep sleep..."] = "Seu pet esta em sono profundo...",
        ["Wait %d min to pet again."] = "Espere %d min para acariciar novamente.",
        ["Petted! Happiness: %d%%"] = "Carinho! Felicidade: %d%%",
        ["Your pet is starving!"] = "Seu pet esta morrendo de fome!",
        ["Your pet fell into deep sleep... Feed it!"] = "Seu pet entrou em sono profundo... Alimente-o!",
        ["Your pet is hungry! (%d%%)"] = "Seu pet esta com fome! (%d%%)",
        ["Streak: %d days!"] = "Streak: %d dias!",
        ["Evolution Crystal earned!"] = "Cristal de Evolucao ganho!",

        -- Evolution stages
        ["Egg"] = "Ovo",
        ["Baby"] = "Filhote",
        ["Young"] = "Jovem",
        ["Adult"] = "Adulto",
        ["Master"] = "Mestre",
        ["Legendary"] = "Lendario",
        ["Night Owl"] = "Coruja Noturna",
        ["Fox"] = "Raposa",
        ["Scholar"] = "Erudito",
        ["Sick"] = "Doente",
        ["SICK"] = "DOENTE",
        ["BORED"] = "ENTEDIADO",
        ["SLEEPY"] = "SONOLENTO",

        -- Pet name
        ["Pet renamed to: %s"] = "Pet renomeado para: %s",

        -- v2.0 Quests & Achievements
        ["Quest complete: %s"] = "Missao completa: %s",
        ["Achievement unlocked: %s"] = "Conquista desbloqueada: %s",
        ["Read 20 pages"] = "Leia 20 paginas",
        ["Feed your pet once"] = "Alimente seu pet uma vez",
        ["Pet your companion 2x"] = "Acaricie seu companheiro 2x",
        ["Read 120 pages this week"] = "Leia 120 paginas esta semana",
        ["Finish 1 book this week"] = "Termine 1 livro esta semana",
        ["First 100 pages"] = "Primeiras 100 paginas",
        ["1,000 pages read"] = "1.000 paginas lidas",
        ["5 books completed"] = "5 livros completos",
        ["7-day streak"] = "Streak de 7 dias",
        ["Reach level 10"] = "Alcance o nivel 10",
        ["Panel mode: %s"] = "Modo do painel: %s",
        ["Notifications: %s"] = "Notificacoes: %s",
        ["Pet animation: %s"] = "Animacao do pet: %s",
        ["Auto"] = "Auto",
        ["Compact"] = "Compacto",
        ["Detailed"] = "Detalhado",
        ["Quiet"] = "Silencioso",
        ["Verbose"] = "Detalhado",
        ["On"] = "Ligada",
        ["Off"] = "Desligada",
    },

    -- ═════════════════════════════════════════
    -- Spanish
    -- ═════════════════════════════════════════
    es = {
        ["View Pet"] = "Ver Mascota",
        ["Feed"] = "Alimentar",
        ["Pet"] = "Acariciar",
        ["Give Treat"] = "Dar Golosina",
        ["Statistics"] = "Estadisticas",
        ["Pages per food: %d"] = "Paginas por comida: %d",
        ["%d pages"] = "%d paginas",
        ["Set to: %d pages per food"] = "Configurado: %d paginas por comida",
        ["Reset Pet"] = "Reiniciar Mascota",
        ["Rename Pet"] = "Renombrar Mascota",
        ["Reset"] = "Reiniciar",
        ["Cancel"] = "Cancelar",
        ["Save"] = "Guardar",
        ["Are you sure you want to reset KoPet?\n\nAll progress will be lost!"] = "Estas seguro de reiniciar KoPet?\n\nTodo el progreso se perdera!",
        ["KoPet reset! New pet created."] = "KoPet reiniciado! Nueva mascota creada.",
        ["Enter a name for your pet:"] = "Escribe un nombre para tu mascota:",
        ["Level: %d"] = "Nivel: %d",
        ["XP: %d / %d (next level)"] = "XP: %d / %d (siguiente nivel)",
        ["Total XP: %d"] = "XP Total: %d",
        ["Hunger: %d%%"] = "Hambre: %d%%",
        ["Happiness: %d%%"] = "Felicidad: %d%%",
        ["Energy: %d%%"] = "Energia: %d%%",
        ["Food: %d"] = "Comida: %d",
        ["Treats: %d"] = "Golosinas: %d",
        ["Crystals: %d"] = "Cristales: %d",
        ["Pages read: %d"] = "Paginas leidas: %d",
        ["Books completed: %d"] = "Libros completados: %d",
        ["Streak: %d days"] = "Racha: %d dias",
        ["Pet age: %d days"] = "Edad de mascota: %d dias",
        ["Deep Sleep..."] = "Sueno Profundo...",
        ["Mood: %s"] = "Humor: %s",
        ["Happy"] = "Feliz",
        ["Normal"] = "Normal",
        ["Hungry"] = "Hambriento",
        ["Sleeping"] = "Durmiendo",
        ["Eating"] = "Comiendo",
        ["Hunger"] = "Hambre",
        ["Happiness"] = "Felicidad",
        ["Energy"] = "Energia",
        ["Level"] = "Nivel",
        ["Lv.%d"] = "Nv.%d",
        ["Food: %d  |  Treats: %d  |  Crystals: %d"] = "Comida: %d  |  Golosinas: %d  |  Cristales: %d",
        ["Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d"] = "Paginas: %d  |  Libros: %d  |  Racha: %d d  |  Edad: %d d",
        ["Total XP: %d  |  Next level: %d XP"] = "XP Total: %d  |  Siguiente nivel: %d XP",
        ["Feed (%d)"] = "Alimentar (%d)",
        ["Give Treat (%d)"] = "Golosina (%d)",
        ["Close"] = "Cerrar",
        ["Level %d!"] = "Nivel %d!",
        ["Food +1! (Total: %d)"] = "Comida +1! (Total: %d)",
        ["Rare Treat! (%d%% of book)"] = "Golosina Rara! (%d%% del libro)",
        ["Streak lost! (%d days)"] = "Racha perdida! (%d dias)",
        ["No food! Read more pages to earn some."] = "Sin comida! Lee mas paginas para ganar.",
        ["Your pet woke up! (-100 XP)"] = "Tu mascota desperto! (-100 XP)",
        ["Fed! Hunger: %d%%"] = "Alimentado! Hambre: %d%%",
        ["No treats! Reach milestones in books."] = "Sin golosinas! Alcanza hitos en libros.",
        ["Treat given! Hunger: %d%% | Happiness: %d%%"] = "Golosina dada! Hambre: %d%% | Felicidad: %d%%",
        ["Your pet is in deep sleep..."] = "Tu mascota esta en sueno profundo...",
        ["Wait %d min to pet again."] = "Espera %d min para acariciar de nuevo.",
        ["Petted! Happiness: %d%%"] = "Acariciado! Felicidad: %d%%",
        ["Your pet is starving!"] = "Tu mascota se muere de hambre!",
        ["Your pet fell into deep sleep... Feed it!"] = "Tu mascota cayo en sueno profundo... Alimentala!",
        ["Your pet is hungry! (%d%%)"] = "Tu mascota tiene hambre! (%d%%)",
        ["Streak: %d days!"] = "Racha: %d dias!",
        ["Evolution Crystal earned!"] = "Cristal de Evolucion ganado!",
        ["Egg"] = "Huevo", ["Baby"] = "Cria", ["Young"] = "Joven",
        ["Adult"] = "Adulto", ["Master"] = "Maestro", ["Legendary"] = "Legendario",
        ["Pet renamed to: %s"] = "Mascota renombrada a: %s",
    },

    -- ═════════════════════════════════════════
    -- French
    -- ═════════════════════════════════════════
    fr = {
        ["View Pet"] = "Voir Animal",
        ["Feed"] = "Nourrir",
        ["Pet"] = "Caresser",
        ["Give Treat"] = "Donner Friandise",
        ["Statistics"] = "Statistiques",
        ["Pages per food: %d"] = "Pages par nourriture: %d",
        ["%d pages"] = "%d pages",
        ["Set to: %d pages per food"] = "Regle: %d pages par nourriture",
        ["Reset Pet"] = "Reinitialiser",
        ["Rename Pet"] = "Renommer",
        ["Reset"] = "Reinitialiser",
        ["Cancel"] = "Annuler",
        ["Save"] = "Enregistrer",
        ["Are you sure you want to reset KoPet?\n\nAll progress will be lost!"] = "Etes-vous sur de reinitialiser KoPet?\n\nToute progression sera perdue!",
        ["KoPet reset! New pet created."] = "KoPet reinitialise! Nouvel animal cree.",
        ["Enter a name for your pet:"] = "Entrez un nom pour votre animal:",
        ["Level: %d"] = "Niveau: %d",
        ["XP: %d / %d (next level)"] = "XP: %d / %d (niveau suivant)",
        ["Total XP: %d"] = "XP Total: %d",
        ["Hunger: %d%%"] = "Faim: %d%%",
        ["Happiness: %d%%"] = "Bonheur: %d%%",
        ["Energy: %d%%"] = "Energie: %d%%",
        ["Food: %d"] = "Nourriture: %d",
        ["Treats: %d"] = "Friandises: %d",
        ["Crystals: %d"] = "Cristaux: %d",
        ["Pages read: %d"] = "Pages lues: %d",
        ["Books completed: %d"] = "Livres termines: %d",
        ["Streak: %d days"] = "Serie: %d jours",
        ["Pet age: %d days"] = "Age: %d jours",
        ["Deep Sleep..."] = "Sommeil Profond...",
        ["Mood: %s"] = "Humeur: %s",
        ["Happy"] = "Heureux",
        ["Normal"] = "Normal",
        ["Hungry"] = "Affame",
        ["Sleeping"] = "Endormi",
        ["Eating"] = "Mange",
        ["Hunger"] = "Faim",
        ["Happiness"] = "Bonheur",
        ["Energy"] = "Energie",
        ["Level"] = "Niveau",
        ["Lv.%d"] = "Nv.%d",
        ["Food: %d  |  Treats: %d  |  Crystals: %d"] = "Nourr: %d  |  Frian: %d  |  Crist: %d",
        ["Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d"] = "Pages: %d  |  Livres: %d  |  Serie: %d j  |  Age: %d j",
        ["Total XP: %d  |  Next level: %d XP"] = "XP Total: %d  |  Niveau suiv: %d XP",
        ["Feed (%d)"] = "Nourrir (%d)",
        ["Give Treat (%d)"] = "Friandise (%d)",
        ["Close"] = "Fermer",
        ["Level %d!"] = "Niveau %d!",
        ["Food +1! (Total: %d)"] = "Nourriture +1! (Total: %d)",
        ["Rare Treat! (%d%% of book)"] = "Friandise Rare! (%d%% du livre)",
        ["Streak lost! (%d days)"] = "Serie perdue! (%d jours)",
        ["No food! Read more pages to earn some."] = "Pas de nourriture! Lisez plus pour en gagner.",
        ["Your pet woke up! (-100 XP)"] = "Votre animal s'est reveille! (-100 XP)",
        ["Fed! Hunger: %d%%"] = "Nourri! Faim: %d%%",
        ["No treats! Reach milestones in books."] = "Pas de friandises! Atteignez des jalons.",
        ["Treat given! Hunger: %d%% | Happiness: %d%%"] = "Friandise! Faim: %d%% | Bonheur: %d%%",
        ["Your pet is in deep sleep..."] = "Votre animal est en sommeil profond...",
        ["Wait %d min to pet again."] = "Attendez %d min pour caresser.",
        ["Petted! Happiness: %d%%"] = "Caresse! Bonheur: %d%%",
        ["Your pet is starving!"] = "Votre animal meurt de faim!",
        ["Your pet fell into deep sleep... Feed it!"] = "Votre animal s'est endormi... Nourrissez-le!",
        ["Your pet is hungry! (%d%%)"] = "Votre animal a faim! (%d%%)",
        ["Streak: %d days!"] = "Serie: %d jours!",
        ["Evolution Crystal earned!"] = "Cristal d'Evolution gagne!",
        ["Egg"] = "Oeuf", ["Baby"] = "Bebe", ["Young"] = "Jeune",
        ["Adult"] = "Adulte", ["Master"] = "Maitre", ["Legendary"] = "Legendaire",
        ["Pet renamed to: %s"] = "Animal renomme: %s",
    },

    -- ═════════════════════════════════════════
    -- German
    -- ═════════════════════════════════════════
    de = {
        ["View Pet"] = "Tier ansehen",
        ["Feed"] = "Fuettern",
        ["Pet"] = "Streicheln",
        ["Give Treat"] = "Leckerli geben",
        ["Statistics"] = "Statistiken",
        ["Pages per food: %d"] = "Seiten pro Futter: %d",
        ["%d pages"] = "%d Seiten",
        ["Set to: %d pages per food"] = "Eingestellt: %d Seiten pro Futter",
        ["Reset Pet"] = "Tier zuruecksetzen",
        ["Rename Pet"] = "Tier umbenennen",
        ["Reset"] = "Zuruecksetzen",
        ["Cancel"] = "Abbrechen",
        ["Save"] = "Speichern",
        ["Are you sure you want to reset KoPet?\n\nAll progress will be lost!"] = "Sicher, dass du KoPet zuruecksetzen willst?\n\nAller Fortschritt geht verloren!",
        ["KoPet reset! New pet created."] = "KoPet zurueckgesetzt! Neues Tier erstellt.",
        ["Enter a name for your pet:"] = "Gib deinem Tier einen Namen:",
        ["Level: %d"] = "Level: %d",
        ["Hunger: %d%%"] = "Hunger: %d%%",
        ["Happiness: %d%%"] = "Freude: %d%%",
        ["Energy: %d%%"] = "Energie: %d%%",
        ["Food: %d"] = "Futter: %d",
        ["Treats: %d"] = "Leckerli: %d",
        ["Crystals: %d"] = "Kristalle: %d",
        ["Pages read: %d"] = "Seiten gelesen: %d",
        ["Books completed: %d"] = "Buecher fertig: %d",
        ["Streak: %d days"] = "Serie: %d Tage",
        ["Pet age: %d days"] = "Alter: %d Tage",
        ["Deep Sleep..."] = "Tiefschlaf...",
        ["Mood: %s"] = "Stimmung: %s",
        ["Happy"] = "Gluecklich",
        ["Normal"] = "Normal",
        ["Hungry"] = "Hungrig",
        ["Sleeping"] = "Schlafend",
        ["Eating"] = "Fressend",
        ["Hunger"] = "Hunger",
        ["Happiness"] = "Freude",
        ["Energy"] = "Energie",
        ["Level"] = "Level",
        ["Lv.%d"] = "Lv.%d",
        ["Food: %d  |  Treats: %d  |  Crystals: %d"] = "Futter: %d  |  Leckerli: %d  |  Kristalle: %d",
        ["Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d"] = "Seiten: %d  |  Buecher: %d  |  Serie: %d T  |  Alter: %d T",
        ["Total XP: %d  |  Next level: %d XP"] = "XP Gesamt: %d  |  Naechstes Level: %d XP",
        ["Feed (%d)"] = "Fuettern (%d)",
        ["Give Treat (%d)"] = "Leckerli (%d)",
        ["Close"] = "Schliessen",
        ["Level %d!"] = "Level %d!",
        ["Food +1! (Total: %d)"] = "Futter +1! (Gesamt: %d)",
        ["Rare Treat! (%d%% of book)"] = "Seltenes Leckerli! (%d%% des Buches)",
        ["No food! Read more pages to earn some."] = "Kein Futter! Lies mehr Seiten.",
        ["Fed! Hunger: %d%%"] = "Gefuettert! Hunger: %d%%",
        ["Petted! Happiness: %d%%"] = "Gestreichelt! Freude: %d%%",
        ["Your pet is starving!"] = "Dein Tier verhungert!",
        ["Your pet fell into deep sleep... Feed it!"] = "Dein Tier ist eingeschlafen... Fuettere es!",
        ["Your pet is hungry! (%d%%)"] = "Dein Tier hat Hunger! (%d%%)",
        ["Streak: %d days!"] = "Serie: %d Tage!",
        ["Evolution Crystal earned!"] = "Evolutionskristall erhalten!",
        ["Egg"] = "Ei", ["Baby"] = "Baby", ["Young"] = "Jung",
        ["Adult"] = "Erwachsen", ["Master"] = "Meister", ["Legendary"] = "Legendaer",
        ["Pet renamed to: %s"] = "Tier umbenannt zu: %s",
    },

    -- ═════════════════════════════════════════
    -- Italian
    -- ═════════════════════════════════════════
    it = {
        ["View Pet"] = "Vedi Animale",
        ["Feed"] = "Nutrire",
        ["Pet"] = "Accarezzare",
        ["Give Treat"] = "Dare Biscotto",
        ["Statistics"] = "Statistiche",
        ["Pages per food: %d"] = "Pagine per cibo: %d",
        ["%d pages"] = "%d pagine",
        ["Set to: %d pages per food"] = "Impostato: %d pagine per cibo",
        ["Reset Pet"] = "Resetta Animale",
        ["Rename Pet"] = "Rinomina Animale",
        ["Reset"] = "Resetta",
        ["Cancel"] = "Annulla",
        ["Save"] = "Salva",
        ["Are you sure you want to reset KoPet?\n\nAll progress will be lost!"] = "Sei sicuro di voler resettare KoPet?\n\nTutti i progressi andranno persi!",
        ["KoPet reset! New pet created."] = "KoPet resettato! Nuovo animale creato.",
        ["Enter a name for your pet:"] = "Inserisci un nome per il tuo animale:",
        ["Level: %d"] = "Livello: %d",
        ["Hunger: %d%%"] = "Fame: %d%%",
        ["Happiness: %d%%"] = "Felicita: %d%%",
        ["Energy: %d%%"] = "Energia: %d%%",
        ["Food: %d"] = "Cibo: %d",
        ["Treats: %d"] = "Biscotti: %d",
        ["Crystals: %d"] = "Cristalli: %d",
        ["Pages read: %d"] = "Pagine lette: %d",
        ["Books completed: %d"] = "Libri completati: %d",
        ["Streak: %d days"] = "Serie: %d giorni",
        ["Pet age: %d days"] = "Eta: %d giorni",
        ["Deep Sleep..."] = "Sonno Profondo...",
        ["Mood: %s"] = "Umore: %s",
        ["Happy"] = "Felice",
        ["Normal"] = "Normale",
        ["Hungry"] = "Affamato",
        ["Sleeping"] = "Addormentato",
        ["Eating"] = "Mangiando",
        ["Hunger"] = "Fame",
        ["Happiness"] = "Felicita",
        ["Energy"] = "Energia",
        ["Level"] = "Livello",
        ["Lv.%d"] = "Lv.%d",
        ["Food: %d  |  Treats: %d  |  Crystals: %d"] = "Cibo: %d  |  Bisc: %d  |  Crist: %d",
        ["Pages: %d  |  Books: %d  |  Streak: %d d  |  Age: %d d"] = "Pagine: %d  |  Libri: %d  |  Serie: %d g  |  Eta: %d g",
        ["Total XP: %d  |  Next level: %d XP"] = "XP Totale: %d  |  Prossimo livello: %d XP",
        ["Feed (%d)"] = "Nutrire (%d)",
        ["Give Treat (%d)"] = "Biscotto (%d)",
        ["Close"] = "Chiudi",
        ["Level %d!"] = "Livello %d!",
        ["Food +1! (Total: %d)"] = "Cibo +1! (Totale: %d)",
        ["Rare Treat! (%d%% of book)"] = "Biscotto Raro! (%d%% del libro)",
        ["No food! Read more pages to earn some."] = "Niente cibo! Leggi piu pagine.",
        ["Fed! Hunger: %d%%"] = "Nutrito! Fame: %d%%",
        ["Petted! Happiness: %d%%"] = "Accarezzato! Felicita: %d%%",
        ["Your pet is starving!"] = "Il tuo animale muore di fame!",
        ["Your pet fell into deep sleep... Feed it!"] = "Il tuo animale si e addormentato... Nutrilo!",
        ["Your pet is hungry! (%d%%)"] = "Il tuo animale ha fame! (%d%%)",
        ["Streak: %d days!"] = "Serie: %d giorni!",
        ["Evolution Crystal earned!"] = "Cristallo di Evoluzione ottenuto!",
        ["Egg"] = "Uovo", ["Baby"] = "Cucciolo", ["Young"] = "Giovane",
        ["Adult"] = "Adulto", ["Master"] = "Maestro", ["Legendary"] = "Leggendario",
        ["Pet renamed to: %s"] = "Animale rinominato: %s",
    },
}

local semantic_en = {
    ["event.level_up"] = "Level %d!",
    ["event.food_earned"] = "Food +1! (Total: %d)",
    ["event.treat_earned"] = "Rare Treat! (%d%% of book)",
    ["event.streak_lost"] = "Streak lost! (%d days)",
    ["event.streak"] = "Streak: %d days!",
    ["event.fed"] = "Fed! Hunger: %d%%",
    ["event.no_food"] = "No food! Read more pages to earn some.",
    ["event.no_treats"] = "No treats! Reach milestones in books.",
    ["event.treat_used"] = "Treat given! Hunger: %d%% | Happiness: %d%%",
    ["event.sleeping"] = "Your pet is in deep sleep...",
    ["event.cooldown"] = "Wait %d min to pet again.",
    ["event.petted"] = "Petted! Happiness: %d%%",
    ["event.starving"] = "Your pet is starving!",
    ["event.deep_sleep"] = "Your pet fell into deep sleep... Feed it!",
    ["event.hungry_warning"] = "Your pet is hungry! (%d%%)",
    ["event.crystal_earned"] = "Evolution Crystal earned!",
    ["event.revived"] = "Your pet woke up! (-100 XP)",
    ["event.medicine_found"] = "Found Medicine!",
    ["event.no_medicine"] = "No medicine! Keep reading while sick to find some.",
    ["event.cured"] = "Cured! Your pet is healthy again.",
    ["event.not_sick"] = "Your pet is healthy! No need for medicine.",
    ["event.is_sick"] = "Your pet is sick and cannot eat. Needs Medicine!",
    ["event.became_sick"] = "Your pet became sick from starvation!",
    ["event.accessory_found"] = "Found accessory: %s",
    ["event.pet_sick"] = "Your pet is sick...",
    ["event.bored"] = "Your pet looks bored. Give it some attention.",
    ["event.sleepy"] = "Your pet is sleepy. Let it rest a bit.",
    ["event.rested"] = "Your pet feels rested again.",

    ["Care"] = "Care",
    ["Quick Action"] = "Quick Action",
    ["Pet Info"] = "Pet Info",
    ["Settings"] = "Settings",
    ["Danger Zone"] = "Danger Zone",
    ["Today Summary"] = "Today Summary",
    ["Care actions: %d"] = "Care actions: %d",
    ["Medicine found: %d"] = "Medicine found: %d",
    ["Accessory: %s"] = "Accessory: %s",
    ["None"] = "None",
    ["SICK"] = "SICK",
    ["BORED"] = "BORED",
    ["SLEEPY"] = "SLEEPY",


    ["Panel mode: %s"] = "Panel mode: %s",
    ["Notifications: %s"] = "Notifications: %s",
    ["Pet animation: %s"] = "Pet animation: %s",
    ["Auto"] = "Auto",
    ["Compact"] = "Compact",
    ["Detailed"] = "Detailed",
    ["Quiet"] = "Quiet",
    ["Verbose"] = "Verbose",
    ["On"] = "On",
    ["Off"] = "Off",
    ["Panel mode: Auto"] = "Panel mode: Auto",
    ["Notifications: Normal"] = "Notifications: Normal",
}

-- Alias: pt matches pt_BR
translations.pt = translations.pt_BR

-- ─────────────────────────────────────────────────────────────
-- Translation function
-- T(key) -> translated string or key itself (English fallback)
-- ─────────────────────────────────────────────────────────────
function KoPetI18n.T(key)
    if not key then return "" end

    local lang = get_lang()
    -- Try exact match first (e.g. "pt_BR")
    if translations[lang] and translations[lang][key] then
        return translations[lang][key]
    end

    -- Try language prefix (e.g. "pt" from "pt_BR")
    local prefix = lang:match("^(%a+)")
    if prefix and translations[prefix] and translations[prefix][key] then
        return translations[prefix][key]
    end

    -- Fallback: return English (the key itself)
    if semantic_en[key] then
        return semantic_en[key]
    end
    return key
end

-- Shortcut: TF(key, ...) = string.format(T(key), ...)
function KoPetI18n.TF(key, ...)
    return string.format(KoPetI18n.T(key), ...)
end

return KoPetI18n
