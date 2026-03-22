var HIGHSCORE_STORAGE_KEY = "praeteritum-werkstatt-highscores";
var HIGHSCORE_PATH = "praeteritum-werkstatt/highscores";
var SESSION_STORAGE_KEY = "praeteritum-werkstatt-sessions";
var SESSION_PATH = "praeteritum-werkstatt/sessions";
var TEACHER_PASSWORD_KEY = "praeteritum-teacher-password";
var DEFAULT_TEACHER_PASSWORD = "44789";
var SESSION_TEXT_COUNT = 10;
var PACKAGE_COLORS = [
  { accent: "rgba(255, 159, 28, 0.22)", strong: "#ff9f1c", soft: "rgba(255, 223, 77, 0.22)" },
  { accent: "rgba(59, 130, 246, 0.22)", strong: "#3b82f6", soft: "rgba(147, 197, 253, 0.22)" },
  { accent: "rgba(34, 197, 94, 0.22)", strong: "#22c55e", soft: "rgba(187, 247, 208, 0.24)" },
  { accent: "rgba(236, 72, 153, 0.22)", strong: "#ec4899", soft: "rgba(251, 207, 232, 0.24)" },
  { accent: "rgba(168, 85, 247, 0.22)", strong: "#a855f7", soft: "rgba(221, 214, 254, 0.24)" }
];

var BASE_TEXTS = [
  {
    title: "Auf dem Schulweg",
    topic: "Schule",
    theme: "school",
    cliparts: ["🏫", "🎒", "📚", "✏️"],
    intro: "Verändere den Text so, dass alles in der Vergangenheit erzählt wird.",
    sentences: [
      { present: "Jeden Morgen geht Nora mit ihrem Bruder zur Schule.", past: "Jeden Morgen ging Nora mit ihrem Bruder zur Schule." },
      { present: "Unterwegs grüßt sie die Bäckerin und schaut in das Schaufenster.", past: "Unterwegs grüßte sie die Bäckerin und schaute in das Schaufenster." },
      { present: "Vor dem Tor trifft Nora ihre Freundin Mila und erzählt von einem lustigen Traum.", past: "Vor dem Tor traf Nora ihre Freundin Mila und erzählte von einem lustigen Traum." },
      { present: "Dann läuft die Klasse hinein und beginnt fröhlich den Tag mit einem Lied.", past: "Dann lief die Klasse hinein und begann fröhlich den Tag mit einem Lied." },
      { present: "Im Flur hängt Nora ihre Jacke an den Haken und ordnet die Hefte für den Unterricht.", past: "Im Flur hängte Nora ihre Jacke an den Haken und ordnete die Hefte für den Unterricht." },
      { present: "Im Klassenzimmer setzt sie sich neben Mila und öffnet gleich ihr Matheheft.", past: "Im Klassenzimmer setzte sie sich neben Mila und öffnete gleich ihr Matheheft." },
      { present: "Die Lehrerin begrüßt die Kinder freundlich und fragt nach den Hausaufgaben.", past: "Die Lehrerin begrüßte die Kinder freundlich und fragte nach den Hausaufgaben." },
      { present: "Nora zeigt am Ende stolz ihr Heft und packt danach den Ranzen aus.", past: "Nora zeigte am Ende stolz ihr Heft und packte danach den Ranzen aus." }
    ]
  },
  {
    title: "Im Schulgarten",
    topic: "Natur",
    theme: "garden",
    cliparts: ["🌱", "🥕", "🌼", "🪴"],
    intro: "Tippe die Wörter an, die du ändern möchtest. Auch andere Wörter lassen sich bearbeiten.",
    sentences: [
      { present: "Heute arbeitet die Klasse im Schulgarten hinter dem Turnplatz.", past: "Heute arbeitete die Klasse im Schulgarten hinter dem Turnplatz." },
      { present: "Lina lockert die Erde mit einer kleinen Harke und zieht vorsichtig Unkraut heraus.", past: "Lina lockerte die Erde mit einer kleinen Harke und zog vorsichtig Unkraut heraus." },
      { present: "Neben ihr gießt Ben die Tomatenpflanzen und zählt die ersten gelben Blüten.", past: "Neben ihr goss Ben die Tomatenpflanzen und zählte die ersten gelben Blüten." },
      { present: "Zum Schluss trägt die Gruppe reife Radieschen ins Klassenzimmer und freut sich über die Ernte.", past: "Zum Schluss trug die Gruppe reife Radieschen ins Klassenzimmer und freute sich über die Ernte." },
      { present: "Vor dem Gehen notiert Lina die Arbeiten im Gartenheft und malt ein kleines Radieschen an den Rand.", past: "Vor dem Gehen notierte Lina die Arbeiten im Gartenheft und malte ein kleines Radieschen an den Rand." },
      { present: "Ben trägt zum Wasserhahn noch eine leere Gießkanne und winkt dann dem Hausmeister zu.", past: "Ben trug zum Wasserhahn noch eine leere Gießkanne und winkte dann dem Hausmeister zu." },
      { present: "Hinter dem Beet sammelt die Gruppe trockene Blätter und legt sie auf einen Haufen.", past: "Hinter dem Beet sammelte die Gruppe trockene Blätter und legte sie auf einen Haufen." },
      { present: "Am Tor bedankt sich Lina bei Ben und schließt das Gartenheft vorsichtig.", past: "Am Tor bedankte sich Lina bei Ben und schloss das Gartenheft vorsichtig." }
    ]
  },
  {
    title: "Besuch bei Oma",
    topic: "Familie",
    theme: "family",
    cliparts: ["🧇", "🥛", "🖼️", "🎵"],
    intro: "Hier darfst du alle Wörter antippen. So kannst du auch Fehler machen und danach entdecken.",
    sentences: [
      { present: "Am Samstag fährt Mila mit ihrer Mutter zu Oma Hedwig.", past: "Am Samstag fuhr Mila mit ihrer Mutter zu Oma Hedwig." },
      { present: "In der Küche stellt Oma frische Waffeln auf den Tisch und schenkt Kakao ein.", past: "In der Küche stellte Oma frische Waffeln auf den Tisch und schenkte Kakao ein." },
      { present: "Mila hilft beim Abräumen und findet dabei eine alte Spieluhr im Schrank.", past: "Mila half beim Abräumen und fand dabei eine alte Spieluhr im Schrank." },
      { present: "Danach sitzt die Familie im Garten und hört eine spannende Geschichte aus Omas Kindheit.", past: "Danach saß die Familie im Garten und hörte eine spannende Geschichte aus Omas Kindheit." },
      { present: "Später zeigt Oma ein Fotoalbum und sucht ein Bild von ihrem ersten Schultag.", past: "Später zeigte Oma ein Fotoalbum und suchte ein Bild von ihrem ersten Schultag." },
      { present: "Beim Abschied drückt Mila ihre Oma fest und verspricht einen baldigen Besuch.", past: "Beim Abschied drückte Mila ihre Oma fest und versprach einen baldigen Besuch." },
      { present: "Vor dem Kuchen holt Oma noch Teller aus dem Schrank und stellt Löffel dazu.", past: "Vor dem Kuchen holte Oma noch Teller aus dem Schrank und stellte Löffel dazu." },
      { present: "Auf dem Heimweg erzählt Mila ihrer Mutter lange von der Spieluhr und lächelt.", past: "Auf dem Heimweg erzählte Mila ihrer Mutter lange von der Spieluhr und lächelte." }
    ]
  },
  {
    title: "Der Ausflug in den Zoo",
    topic: "Ausflug",
    theme: "zoo",
    cliparts: ["🐧", "🦭", "🐠", "🎟️"],
    intro: "Die Sätze sind ungefähr so lang wie kleine Lesetexte aus der Schule. Arbeite Satz für Satz.",
    sentences: [
      { present: "Heute besucht die Klasse den Zoo am Stadtrand.", past: "Heute besuchte die Klasse den Zoo am Stadtrand." },
      { present: "Zuerst beobachtet Aylin die Pinguine und liest jedes Schild ganz genau.", past: "Zuerst beobachtete Aylin die Pinguine und las jedes Schild ganz genau." },
      { present: "Später zeigt der Tierpfleger eine Robbe und wirft ihr einen silbernen Fisch zu.", past: "Später zeigte der Tierpfleger eine Robbe und warf ihr einen silbernen Fisch zu." },
      { present: "Auf dem Rückweg kauft die Gruppe Postkarten und trägt viele neue Ideen ins Klassenzimmer.", past: "Auf dem Rückweg kaufte die Gruppe Postkarten und trug viele neue Ideen ins Klassenzimmer." },
      { present: "Im Bus spricht Aylin lange über die Robbe und zeichnet ihr später eine silberne Nase.", past: "Im Bus sprach Aylin lange über die Robbe und zeichnete ihr später eine silberne Nase." },
      { present: "Zurück in der Schule klebt die Klasse Eintrittskarten ins Ausflugsheft und schreibt kurze Notizen.", past: "Zurück in der Schule klebte die Klasse Eintrittskarten ins Ausflugsheft und schrieb kurze Notizen." },
      { present: "Vor dem Löwengehege bleibt die Gruppe stehen und schaut neugierig durch die Scheibe.", past: "Vor dem Löwengehege blieb die Gruppe stehen und schaute neugierig durch die Scheibe." },
      { present: "Am Ausgang winkt Aylin dem Tierpfleger noch einmal und hält ihr Ticket fest.", past: "Am Ausgang winkte Aylin dem Tierpfleger noch einmal und hielt ihr Ticket fest." }
    ]
  },
  {
    title: "Der Abend am See",
    topic: "Ferien",
    theme: "camp",
    cliparts: ["⛺", "🛶", "🌅", "📚"],
    intro: "Zum Üben ist es gut, nach jeder Änderung kurz zu lesen, ob der Satz noch sinnvoll klingt.",
    sentences: [
      { present: "In den Ferien sitzt Timo mit seiner Familie am See.", past: "In den Ferien saß Timo mit seiner Familie am See." },
      { present: "Sein Vater wirft kleine Steine übers Wasser und zählt jeden flachen Sprung.", past: "Sein Vater warf kleine Steine übers Wasser und zählte jeden flachen Sprung." },
      { present: "Timo sammelt währenddessen Schilf am Ufer und baut daraus ein kleines Boot.", past: "Timo sammelte währenddessen Schilf am Ufer und baute daraus ein kleines Boot." },
      { present: "Als die Sonne untergeht, packt die Familie alles ein und geht langsam zum Zelt zurück.", past: "Als die Sonne unterging, packte die Familie alles ein und ging langsam zum Zelt zurück." },
      { present: "Vor dem Schlafen zündet die Mutter eine Lampe an und liest noch eine kurze Geschichte.", past: "Vor dem Schlafen zündete die Mutter eine Lampe an und las noch eine kurze Geschichte." },
      { present: "Timo hört leise zu und deckt sein Boot für die Nacht mit Schilf zu.", past: "Timo hörte leise zu und deckte sein Boot für die Nacht mit Schilf zu." },
      { present: "Am Ufer sucht Timo noch einen flachen Stein und legt ihn neben das Boot.", past: "Am Ufer suchte Timo noch einen flachen Stein und legte ihn neben das Boot." },
      { present: "Vor dem Einschlafen schaut die Familie lange in den Himmel und zählt die Sterne.", past: "Vor dem Einschlafen schaute die Familie lange in den Himmel und zählte die Sterne." }
    ]
  }
];

var NAME_VARIANTS = [
  ["Nora", "Mila"], ["Emir", "Lotte"], ["Aylin", "Ben"], ["Mats", "Nele"], ["Sofia", "Timo"],
  ["Lina", "Jonas"], ["Emma", "Levin"], ["Mira", "Luca"], ["Kira", "Sam"], ["Jule", "Amir"]
];
var TITLE_PREFIXES = ["Bunt", "Extra", "Neu", "Kunterbunt", "Fröhlich", "Spannend", "Klug", "Munter", "Sonnig", "Lustig"];
if (window.PRAETERITUM_TEXT_LIBRARY && window.PRAETERITUM_TEXT_LIBRARY.length) {
  BASE_TEXTS = polishTextLibrary(normalizeTextLibrary(window.PRAETERITUM_TEXT_LIBRARY));
}
var PUNCTUATION = { ".": true, ",": true, "!": true, "?": true, ";": true, ":": true };
var TEXTS = buildTexts();

var setupScreen = document.getElementById("setup-screen");
var trainerShell = document.getElementById("trainer-shell");
var setupForm = document.getElementById("setup-form");
var startButton = document.getElementById("start-button");
var playerNameInput = document.getElementById("player-name");
var setupError = document.getElementById("setup-error");
var bootStatus = document.getElementById("boot-status");
var highscoreList = document.getElementById("highscore-list");
var trainerHighscoreList = document.getElementById("trainer-highscore-list");
var teacherOpenButton = document.getElementById("teacher-open-button");
var trainerTeacherOpenButton = document.getElementById("trainer-teacher-open-button");
var titleOutput = document.getElementById("text-title");
var topicOutput = document.getElementById("text-topic");
var progressOutput = document.getElementById("text-progress");
var introOutput = document.getElementById("text-intro");
var sentenceList = document.getElementById("sentence-list");
var feedbackBox = document.getElementById("feedback-box");
var checkAllButton = document.getElementById("check-all-button");
var resetButton = document.getElementById("reset-button");
var nextButton = document.getElementById("next-button");
var menuButton = document.getElementById("menu-button");
var themeStage = document.getElementById("theme-stage");
var clipartList = document.getElementById("clipart-list");
var playerOutput = document.getElementById("player-output");
var scoreOutput = document.getElementById("score-output");
var attemptsOutput = document.getElementById("attempts-output");
var teacherDialog = document.getElementById("teacher-dialog");
var teacherError = document.getElementById("teacher-error");
var teacherPasswordInput = document.getElementById("teacher-password-input");
var teacherLoginButton = document.getElementById("teacher-login-button");
var teacherLoginSection = document.getElementById("teacher-login-section");
var teacherContentSection = document.getElementById("teacher-content-section");
var teacherHighscoreList = document.getElementById("teacher-highscore-list");
var teacherNewPasswordInput = document.getElementById("teacher-new-password-input");
var teacherSavePasswordButton = document.getElementById("teacher-save-password-button");
var teacherResetStatsButton = document.getElementById("teacher-reset-stats-button");
var teacherLogoutButton = document.getElementById("teacher-logout-button");
var teacherStatsPlayers = document.getElementById("teacher-stats-players");
var teacherStatsTexts = document.getElementById("teacher-stats-texts");
var teacherStatsEditedWords = document.getElementById("teacher-stats-edited-words");
var teacherStatsMissedWords = document.getElementById("teacher-stats-missed-words");
var exportHighscoreButton = document.getElementById("export-highscore-button");
var exportTextsButton = document.getElementById("export-texts-button");
var exportEditedWordsButton = document.getElementById("export-edited-words-button");
var exportMissedWordsButton = document.getElementById("export-missed-words-button");
var exportPlayersButton = document.getElementById("export-players-button");

var state = {
  playerName: "",
  sessionId: "",
  score: 0,
  totalChecks: 0,
  sessionPointer: 0,
  sessionOrder: [],
  currentTokens: [],
  checkedSentences: [],
  sentenceAttempts: [],
  revealedSolutions: [],
  sentenceResolved: [],
  sentenceScores: [],
  completedTextScores: [],
  textCheckCounts: [],
  savedTextEntries: [],
  savedSentenceEntries: [],
  currentWrongEditedWords: [],
  currentUneditedWrongWords: [],
  currentEditedCorrectInputs: 0,
  currentEditedWrongInputs: 0,
  sessionFinished: false,
  sessionStartedAt: 0
};

var firebaseDatabase = null;
var firebaseEnabled = false;
var teacherUnlocked = false;

initializeFirebase();

renderHighscores();
window.__appReady = true;
if (bootStatus) {
  bootStatus.textContent = "";
}

setupForm.onsubmit = handleStart;
startButton.onclick = handleStart;
checkAllButton.onclick = checkAllSentences;
resetButton.onclick = resetCurrentText;
nextButton.onclick = goToNextText;
menuButton.onclick = showSetupScreen;
teacherOpenButton.onclick = openTeacherDialog;
trainerTeacherOpenButton.onclick = openTeacherDialog;
teacherLoginButton.onclick = unlockTeacherArea;
teacherSavePasswordButton.onclick = saveTeacherPassword;
teacherResetStatsButton.onclick = resetAllTeacherStats;
teacherLogoutButton.onclick = lockTeacherArea;
exportHighscoreButton.onclick = function () { exportTeacherTable(teacherHighscoreList, "highscore-gesamtwertung"); };
exportTextsButton.onclick = function () { exportTeacherTable(teacherStatsTexts, "texte-im-ueberblick"); };
exportEditedWordsButton.onclick = function () { exportTeacherTable(teacherStatsEditedWords, "falsch-bearbeitete-woerter"); };
exportMissedWordsButton.onclick = function () { exportTeacherTable(teacherStatsMissedWords, "nicht-bearbeitete-woerter"); };
exportPlayersButton.onclick = function () { exportTeacherTable(teacherStatsPlayers, "bearbeitete-texte-pro-kind"); };

function buildTexts() {
  return ensureTokenizedTexts(BASE_TEXTS);
}

function refreshExtendedTextLibrary() {
  if (!window.PRAETERITUM_TEXT_LIBRARY || !window.PRAETERITUM_TEXT_LIBRARY.length) {
    return false;
  }
  BASE_TEXTS = polishTextLibrary(normalizeTextLibrary(window.PRAETERITUM_TEXT_LIBRARY));
  TEXTS = buildTexts();
  return true;
}

function ensureTokenizedTexts(texts) {
  var normalized = [];
  var textIndex;
  var sentenceIndex;
  var text;
  var sentence;
  for (textIndex = 0; textIndex < texts.length; textIndex += 1) {
    text = {
      title: texts[textIndex].title,
      topic: texts[textIndex].topic,
      theme: texts[textIndex].theme,
      cliparts: (texts[textIndex].cliparts || []).slice(),
      intro: texts[textIndex].intro,
      sentences: []
    };
    for (sentenceIndex = 0; sentenceIndex < texts[textIndex].sentences.length; sentenceIndex += 1) {
      sentence = texts[textIndex].sentences[sentenceIndex];
      text.sentences.push({
        present: typeof sentence.present === "string" ? tokenizeSentence(sentence.present) : sentence.present.slice(),
        past: typeof sentence.past === "string" ? tokenizeSentence(sentence.past) : sentence.past.slice(),
        answer: sentence.answer
          ? (typeof sentence.answer === "string" ? tokenizeSentence(sentence.answer) : sentence.answer.slice())
          : null
      });
    }
    normalized.push(text);
  }
  return normalized;
}

function normalizeTextLibrary(value) {
  if (Object.prototype.toString.call(value) === "[object Array]") {
    var list = [];
    var arrayIndex;
    for (arrayIndex = 0; arrayIndex < value.length; arrayIndex += 1) {
      list.push(normalizeTextLibrary(value[arrayIndex]));
    }
    return list;
  }
  if (typeof value === "string") {
    return normalizeGermanText(value);
  }
  if (value && typeof value === "object") {
    var copy = {};
    var key;
    for (key in value) {
      if (Object.prototype.hasOwnProperty.call(value, key)) {
        copy[key] = normalizeTextLibrary(value[key]);
      }
    }
    return copy;
  }
  return value;
}

function polishTextLibrary(texts) {
  var polished = [];
  var textIndex;
  var sentenceIndex;
  var sentence;
  var present;
  var past;
  for (textIndex = 0; textIndex < texts.length; textIndex += 1) {
    for (sentenceIndex = 0; sentenceIndex < texts[textIndex].sentences.length; sentenceIndex += 1) {
      sentence = texts[textIndex].sentences[sentenceIndex];
      present = typeof sentence.present === "string" ? sentence.present : joinTokens(sentence.present);
      past = typeof sentence.past === "string" ? sentence.past : joinTokens(sentence.past);

      sentence.present = tokenizeSentence(present);
      sentence.past = tokenizeSentence(past);
      sentence.answer = buildVerbOnlyPastTokens(sentence.present, sentence.past);
    }
    polished.push(texts[textIndex]);
  }
  return polished;
}

function buildVerbOnlyPastTokens(presentTokens, pastTokens) {
  var rows = [];
  var presentMatched = [];
  var pastMatched = [];
  var presentIndex;
  var pastIndex;
  var rebuilt = [];
  var changedPastTokens = [];
  var replacementIndex = 0;

  for (presentIndex = 0; presentIndex <= presentTokens.length; presentIndex += 1) {
    rows[presentIndex] = [];
    for (pastIndex = 0; pastIndex <= pastTokens.length; pastIndex += 1) {
      rows[presentIndex][pastIndex] = 0;
    }
  }

  for (presentIndex = presentTokens.length - 1; presentIndex >= 0; presentIndex -= 1) {
    for (pastIndex = pastTokens.length - 1; pastIndex >= 0; pastIndex -= 1) {
      if (presentTokens[presentIndex] === pastTokens[pastIndex]) {
        rows[presentIndex][pastIndex] = rows[presentIndex + 1][pastIndex + 1] + 1;
      } else if (rows[presentIndex + 1][pastIndex] >= rows[presentIndex][pastIndex + 1]) {
        rows[presentIndex][pastIndex] = rows[presentIndex + 1][pastIndex];
      } else {
        rows[presentIndex][pastIndex] = rows[presentIndex][pastIndex + 1];
      }
    }
  }

  presentIndex = 0;
  pastIndex = 0;
  while (presentIndex < presentTokens.length && pastIndex < pastTokens.length) {
    if (presentTokens[presentIndex] === pastTokens[pastIndex]) {
      presentMatched[presentIndex] = true;
      pastMatched[pastIndex] = true;
      presentIndex += 1;
      pastIndex += 1;
    } else if (rows[presentIndex + 1][pastIndex] >= rows[presentIndex][pastIndex + 1]) {
      presentIndex += 1;
    } else {
      pastIndex += 1;
    }
  }

  for (pastIndex = 0; pastIndex < pastTokens.length; pastIndex += 1) {
    if (!pastMatched[pastIndex] && !PUNCTUATION[pastTokens[pastIndex]]) {
      changedPastTokens.push(pastTokens[pastIndex]);
    }
  }

  for (presentIndex = 0; presentIndex < presentTokens.length; presentIndex += 1) {
    if (!presentMatched[presentIndex] && !PUNCTUATION[presentTokens[presentIndex]]) {
      if (replacementIndex < changedPastTokens.length) {
        rebuilt.push(changedPastTokens[replacementIndex]);
        replacementIndex += 1;
      } else {
        rebuilt.push(presentTokens[presentIndex]);
      }
    } else {
      rebuilt.push(presentTokens[presentIndex]);
    }
  }

  return rebuilt;
}

function getExpectedSentenceTokens(sentence) {
  return sentence.answer && sentence.answer.length ? sentence.answer : sentence.past;
}

function normalizeGermanText(value) {
  var output = String(value);
  var replacements = [
    ["Frueh", "Früh"], ["frueh", "früh"], ["Bae", "Bä"], ["bae", "bä"], ["Kue", "Kü"], ["kue", "kü"],
    ["Rue", "Rü"], ["rue", "rü"], ["Fue", "Fü"], ["fue", "fü"], ["Mue", "Mü"], ["mue", "mü"],
    ["Loe", "Lö"], ["loe", "lö"]
  ];
  var locked = [
    ["Schluß", "Schluss"], ["müßte", "müsste"], ["daß", "dass"], ["Fluß", "Fluss"],
    ["große", "große"], ["Große", "Große"], ["gruüne", "grüne"], ["gruünen", "grünen"],
    ["gruüner", "grüner"], ["gruünes", "grünes"], ["Püzzle", "Puzzle"], ["Täßa", "Tessa"],
    ["Büsch", "Busch"], ["Müra", "Mira"], ["Müila", "Mila"], ["Füna", "Fina"], ["Nöah", "Noah"],
    ["Töm", "Tom"], ["Löwe", "Löwe"], ["Löwen", "Löwen"], ["Nöe", "Noe"], ["Zöe", "Zoe"]
  ];
  var i;
  for (i = 0; i < replacements.length; i += 1) {
    output = output.split(replacements[i][0]).join(replacements[i][1]);
  }
  for (i = 0; i < locked.length; i += 1) {
    output = output.split(locked[i][0]).join(locked[i][1]);
  }
  output = output.replace(/(^|[\s(])fuß(?=[\s).,!?:;]|$)/g, "$1Fuß");
  output = output.replace(/gruü/g, "grü");
  output = output.replace(/Gruü/g, "Grü");
  output = output.replace(/Zähne?räder/g, "Zahnräder");
  output = output.replace(/Strassenbahn/g, "Straßenbahn");
  output = output.replace(/Schulstrasse/g, "Schulstraße");
  output = output.replace(/grosse/g, "große");
  output = output.replace(/Grossen/g, "Großen");
  output = output.replace(/grossen/g, "großen");
  output = output.replace(/grosser/g, "großer");
  output = output.replace(/grosses/g, "großes");
  output = output.replace(/grossen/g, "großen");
  output = output.replace(/heisst/g, "heißt");
  output = output.replace(/weisse/g, "weiße");
  output = output.replace(/gruesst/g, "grüßt");
  output = output.replace(/Wörterbuch/g, "Wörterbuch");
  output = output.replace(/Wörter/g, "Wörter");
  output = output.replace(/Überraschungsbuch/g, "Überraschungsbuch");
  output = output.replace(/Überraschung/g, "Überraschung");
  output = output.replace(/Oeff/g, "Öff");
  output = output.replace(/oeff/g, "öff");
  return output;
}

function createVariant(baseText, baseIndex, variantIndex) {
  var names = NAME_VARIANTS[(baseIndex + variantIndex) % NAME_VARIANTS.length];
  var text = {
    title: TITLE_PREFIXES[variantIndex % TITLE_PREFIXES.length] + ": " + baseText.title,
    topic: baseText.topic,
    theme: baseText.theme,
    cliparts: baseText.cliparts.slice(),
    intro: baseText.intro,
    sentences: []
  };
  var i;
  for (i = 0; i < baseText.sentences.length; i += 1) {
    text.sentences.push({
      present: tokenizeSentence(replaceNames(baseText.sentences[i].present, names[0], names[1])),
      past: tokenizeSentence(replaceNames(baseText.sentences[i].past, names[0], names[1]))
    });
  }
  return text;
}

function replaceNames(sentence, firstName, secondName) {
  var names = ["Nora", "Mila", "Lina", "Ben", "Aylin", "Timo"];
  var output = sentence;
  var replaced = 0;
  var i;
  for (i = 0; i < names.length; i += 1) {
    if (output.indexOf(names[i]) !== -1) {
      output = output.replace(names[i], replaced === 0 ? firstName : secondName);
      replaced += 1;
      if (replaced > 1) {
        break;
      }
    }
  }
  return output;
}

function tokenizeSentence(sentence) {
  var matches = sentence.match(/[A-Za-zÄÖÜäöüß]+(?:-[A-Za-zÄÖÜäöüß]+)*|[0-9]+|[,.;:!?]/g);
  return matches || [];
}

function handleStart(event) {
  var name = playerNameInput.value.replace(/^\s+|\s+$/g, "");
  if (event && event.preventDefault) {
    event.preventDefault();
  }
  if (!name) {
    setupError.textContent = "Bitte trage zuerst deinen Namen ein.";
    return false;
  }
  setupError.textContent = "";
  refreshExtendedTextLibrary();
  state.playerName = name;
  state.sessionId = createEntryId();
  state.score = 0;
  state.totalChecks = 0;
  state.sessionPointer = 0;
  state.completedTextScores = [];
  state.textCheckCounts = [];
  state.savedTextEntries = [];
  state.savedSentenceEntries = [];
  state.sessionFinished = false;
  state.sessionStartedAt = new Date().getTime();
  saveSessionStart({
    sessionId: state.sessionId,
    name: state.playerName,
    startedAt: new Date().toISOString()
  });
  state.sessionOrder = createSessionOrder(name);
  setupScreen.className = "panel setup-panel is-hidden";
  trainerShell.className = "layout";
  loadCurrentText();
  return false;
}

function createIndexList(length) {
  var list = [];
  var i;
  for (i = 0; i < length; i += 1) {
    list.push(i);
  }
  return list;
}

function createSessionOrder(name) {
  return seededShuffle(createIndexList(TEXTS.length), createSeedFromName(name)).slice(0, SESSION_TEXT_COUNT);
}

function loadCurrentText() {
  var text = getCurrentText();
  var i;
  state.currentTokens = [];
  state.checkedSentences = [];
  state.sentenceAttempts = [];
  state.revealedSolutions = [];
  state.sentenceResolved = [];
  state.sentenceScores = [];
  state.savedSentenceEntries[state.sessionPointer] = [];
  state.currentWrongEditedWords = [];
  state.currentUneditedWrongWords = [];
  state.currentEditedCorrectInputs = 0;
  state.currentEditedWrongInputs = 0;
  for (i = 0; i < text.sentences.length; i += 1) {
    state.currentTokens.push(copyTokens(text.sentences[i].present));
    state.checkedSentences.push(false);
    state.sentenceAttempts.push(0);
    state.revealedSolutions.push(false);
    state.sentenceResolved.push(false);
    state.sentenceScores.push(0);
  }
  applyPackageColors();
  document.body.setAttribute("data-theme", text.theme);
  themeStage.setAttribute("data-theme", text.theme);
  titleOutput.textContent = text.title;
  topicOutput.textContent = text.topic;
  progressOutput.textContent = String(state.sessionPointer + 1) + " / " + String(SESSION_TEXT_COUNT);
  introOutput.textContent = text.intro;
  playerOutput.textContent = state.playerName;
  scoreOutput.textContent = String(getCurrentTextScore());
  attemptsOutput.textContent = String(state.totalChecks);
  feedbackBox.className = "feedback-box";
  feedbackBox.textContent = "Tippe ein Wort im Text an und ändere es. Alle Wörter dürfen bearbeitet werden.";
  nextButton.disabled = true;
  nextButton.textContent = state.sessionPointer === SESSION_TEXT_COUNT - 1 ? "Runde abschließen" : "Nächster Text";
  renderThemeStage(text);
  renderSentences();
}

function copyTokens(tokens) {
  var list = [];
  var i;
  for (i = 0; i < tokens.length; i += 1) {
    list.push({ value: tokens[i], original: tokens[i] });
  }
  return list;
}

function renderThemeStage(text) {
  var i;
  clipartList.innerHTML = "";
  for (i = 0; i < text.cliparts.length; i += 1) {
    var item = document.createElement("div");
    var emoji = document.createElement("span");
    item.className = "clipart-chip";
    item.style.setProperty("--twist", i % 2 === 0 ? "-4" : "4");
    emoji.className = "clipart-chip__emoji";
    emoji.textContent = text.cliparts[i];
    item.appendChild(emoji);
    clipartList.appendChild(item);
  }
}

function renderSentences() {
  var text = getCurrentText();
  var i;
  sentenceList.innerHTML = "";
  for (i = 0; i < text.sentences.length; i += 1) {
    renderSentenceCard(text, i);
  }
}

function renderSentenceCard(text, sentenceIndex) {
  var sentence = text.sentences[sentenceIndex];
  var sentenceCard = document.createElement("article");
  var sentenceHead = document.createElement("div");
  var sentenceLabel = document.createElement("p");
  var sentenceHeadRight = document.createElement("div");
  var sentenceState = document.createElement("button");
  var sentenceClipartChip = document.createElement("div");
  var sentenceClipartEmoji = document.createElement("span");
  var wordsRow = document.createElement("div");
  var i;

  sentenceCard.className = "sentence-card";
  sentenceCard.setAttribute("data-theme", text.theme);
  if (state.checkedSentences[sentenceIndex]) {
    sentenceCard.className += sentenceIsCorrect(sentenceIndex) ? " is-correct" : " has-errors";
  }

  sentenceHead.className = "sentence-card__head";
  sentenceLabel.className = "sentence-label";
  sentenceLabel.textContent = "Satz " + String(sentenceIndex + 1);

  sentenceState.className = "sentence-state " + getSentenceStatusClass(sentenceIndex);
  sentenceState.type = "button";
  sentenceState.textContent = getSentenceStatusText(sentenceIndex);
  sentenceState.onclick = createCheckHandler(sentenceIndex);

  sentenceClipartChip.className = "sentence-clipart";
  sentenceClipartEmoji.className = "sentence-clipart__emoji";
  sentenceClipartEmoji.textContent = text.cliparts[sentenceIndex % text.cliparts.length];
  sentenceClipartChip.appendChild(sentenceClipartEmoji);

  sentenceHeadRight.className = "sentence-head-right";
  sentenceHeadRight.appendChild(sentenceState);
  sentenceHeadRight.appendChild(sentenceClipartChip);

  sentenceHead.appendChild(sentenceLabel);
  sentenceHead.appendChild(sentenceHeadRight);

  wordsRow.className = "sentence-card__words";
  for (i = 0; i < sentence.present.length; i += 1) {
    wordsRow.appendChild(createTokenElement(sentenceIndex, i));
  }

  sentenceCard.appendChild(sentenceHead);
  sentenceCard.appendChild(wordsRow);
  if (state.revealedSolutions[sentenceIndex]) {
    sentenceCard.appendChild(createSolutionBox(sentenceIndex));
  }
  sentenceList.appendChild(sentenceCard);
}

function loadOptionalScript(src, onLoad, onError) {
  var script = document.createElement("script");
  script.src = src;
  script.onload = onLoad || function () {};
  script.onerror = onError || function () {};
  document.head.appendChild(script);
}

function startOptionalIntegrations() {
  if (window.__optionalLoadsStarted) {
    return;
  }
  window.__optionalLoadsStarted = true;

  loadOptionalScript("./text-library-custom.js?v=20260321-5", function () {
    if (!state.playerName) {
      refreshExtendedTextLibrary();
    }
  });

  loadOptionalScript("./firebase-config.js", function () {
    loadOptionalScript("https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js", function () {
      loadOptionalScript("https://www.gstatic.com/firebasejs/11.6.0/firebase-database-compat.js", function () {
        initializeFirebase();
        renderHighscores();
      });
    });
  });
}

window.setTimeout(function () {
  try {
    startOptionalIntegrations();
  } catch (error) {
  }
}, 0);

function createTokenElement(sentenceIndex, tokenIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var tokenState = state.currentTokens[sentenceIndex][tokenIndex];
  var expectedTokens = getExpectedSentenceTokens(sentence);
  var expected = expectedTokens[tokenIndex];
  var wasEdited = tokenState.value !== tokenState.original;
  var element;
  if (PUNCTUATION[tokenState.original]) {
    element = document.createElement("span");
    element.className = "word-punctuation";
    element.textContent = tokenState.value;
    return element;
  }
  element = document.createElement("button");
  element.type = "button";
  element.className = "word-chip";
  element.textContent = tokenState.value;
  element.onclick = createEditHandler(sentenceIndex, tokenIndex);
  if (wasEdited) {
    element.className += " is-edited";
  }
  if (state.checkedSentences[sentenceIndex]) {
    if (wasEdited && tokenState.value === expected) {
      element.className += " is-correct";
    } else if (wasEdited && tokenState.value !== expected) {
      element.className += " is-wrong";
    } else if (state.revealedSolutions[sentenceIndex] && tokenState.value !== expected) {
      element.className += " is-wrong";
    }
  }
  return element;
}

function createEditHandler(sentenceIndex, tokenIndex) {
  return function () {
    var tokenState = state.currentTokens[sentenceIndex][tokenIndex];
    var nextValue = window.prompt("Wort ändern", tokenState.value);
    if (nextValue === null) {
      return;
    }
    nextValue = nextValue.replace(/^\s+|\s+$/g, "");
    state.currentTokens[sentenceIndex][tokenIndex].value = nextValue || tokenState.original;
    state.checkedSentences[sentenceIndex] = false;
    renderSentences();
  };
}

function createCheckHandler(sentenceIndex) {
  return function () {
    checkSentence(sentenceIndex);
  };
}

function createSolutionBox(sentenceIndex) {
  var solutionBox = document.createElement("div");
  var solutionLabel = document.createElement("strong");
  var solutionText = document.createElement("span");
  solutionBox.className = "solution-box";
  solutionLabel.textContent = "Lösung ab dem 3. Fehlversuch:";
  solutionText.textContent = joinTokens(getCurrentText().sentences[sentenceIndex].past);
  solutionBox.appendChild(solutionLabel);
  solutionBox.appendChild(solutionText);
  return solutionBox;
}

function checkSentence(sentenceIndex) {
  var correct = sentenceIsCorrect(sentenceIndex);
  state.checkedSentences[sentenceIndex] = true;
  state.totalChecks += 1;
  state.textCheckCounts[state.sessionPointer] = (state.textCheckCounts[state.sessionPointer] || 0) + 1;
  collectEditedInputStats(sentenceIndex);
  attemptsOutput.textContent = String(state.totalChecks);
  if (correct) {
    awardSentencePoints(sentenceIndex);
    renderSentences();
    scoreOutput.textContent = String(getCurrentTextScore());
    if (allSentencesCorrect() && allSentencesResolved()) {
      nextButton.disabled = false;
      saveCompletedTextHighscore();
      renderHighscores();
      feedbackBox.className = "feedback-box is-success";
      feedbackBox.textContent = "Super. Alle Sätze dieses Textes stimmen.";
    } else {
      feedbackBox.className = "feedback-box is-success";
      feedbackBox.textContent = "Satz " + String(sentenceIndex + 1) + " stimmt.";
    }
    return;
  }
  state.sentenceAttempts[sentenceIndex] += 1;
  collectSentenceMistakes(sentenceIndex);
  if (state.sentenceAttempts[sentenceIndex] >= 3) {
    state.revealedSolutions[sentenceIndex] = true;
  }
  renderSentences();
  feedbackBox.className = "feedback-box is-warning";
  feedbackBox.textContent = state.revealedSolutions[sentenceIndex]
    ? "Satz " + String(sentenceIndex + 1) + " ist zum 3. Mal noch nicht richtig. Die Lösung wird jetzt angezeigt."
    : "Satz " + String(sentenceIndex + 1) + " ist noch nicht richtig. Versuch " + String(state.sentenceAttempts[sentenceIndex]) + " von 3.";
}

function checkAllSentences() {
  var i;
  for (i = 0; i < getCurrentText().sentences.length; i += 1) {
    if (!sentenceIsCorrect(i)) {
      checkSentence(i);
    } else if (!state.checkedSentences[i]) {
      checkSentence(i);
    }
  }
  if (allSentencesCorrect() && allSentencesResolved()) {
    nextButton.disabled = false;
    saveCompletedTextHighscore();
    renderHighscores();
    feedbackBox.className = "feedback-box is-success";
    feedbackBox.textContent = "Alle Sätze wurden kontrolliert. Dieser Text ist fertig.";
  } else {
    feedbackBox.className = "feedback-box is-warning";
    feedbackBox.textContent = "Alle Sätze wurden kontrolliert. Schau dir die roten Wörter noch einmal an.";
  }
}

function sentenceIsCorrect(sentenceIndex) {
  var current = state.currentTokens[sentenceIndex];
  var expected = getExpectedSentenceTokens(getCurrentText().sentences[sentenceIndex]);
  var i;
  for (i = 0; i < current.length; i += 1) {
    if (current[i].value !== expected[i]) {
      return false;
    }
  }
  return true;
}

function allSentencesCorrect() {
  var i;
  for (i = 0; i < getCurrentText().sentences.length; i += 1) {
    if (!sentenceIsCorrect(i)) {
      return false;
    }
  }
  return true;
}

function allSentencesResolved() {
  var i;
  for (i = 0; i < state.sentenceResolved.length; i += 1) {
    if (!state.sentenceResolved[i]) {
      return false;
    }
  }
  return true;
}

function awardSentencePoints(sentenceIndex) {
  var wrongAttempts;
  if (state.sentenceResolved[sentenceIndex]) {
    return;
  }
  wrongAttempts = state.sentenceAttempts[sentenceIndex];
  state.sentenceResolved[sentenceIndex] = true;
  state.sentenceScores[sentenceIndex] = wrongAttempts === 0 ? 3 : wrongAttempts === 1 ? 2 : 1;
  state.score += state.sentenceScores[sentenceIndex];
}

function resetCurrentText() {
  loadCurrentText();
}

function goToNextText() {
  if (nextButton.disabled) {
    return;
  }
  if (state.sessionPointer >= SESSION_TEXT_COUNT - 1) {
    finishSession();
    return;
  }
  state.sessionPointer += 1;
  loadCurrentText();
}

function finishSession() {
  if (state.sessionFinished) {
    showSetupScreen();
    return;
  }
  state.sessionFinished = true;
  renderHighscores();
  feedbackBox.className = "feedback-box is-success";
  feedbackBox.textContent = "Runde beendet. " + state.playerName + " erreicht " + String(state.score) + " Punkte bei " + String(state.totalChecks) + " Kontrollen.";
}

function showSetupScreen() {
  trainerShell.className = "layout is-hidden";
  setupScreen.className = "panel setup-panel";
  renderHighscores();
}

function getLocalHighscores() {
  var rawValue = localStorage.getItem(HIGHSCORE_STORAGE_KEY);
  if (!rawValue) {
    return [];
  }
  try {
    return JSON.parse(rawValue) || [];
  } catch (error) {
    return [];
  }
}

function getLocalSessions() {
  var rawValue = localStorage.getItem(SESSION_STORAGE_KEY);
  if (!rawValue) {
    return [];
  }
  try {
    return JSON.parse(rawValue) || [];
  } catch (error) {
    return [];
  }
}

function buildPlayerSummaryRows(entries, sessions) {
  var map = {};
  var rows = [];
  var i;
  var sessionMap = countSessionsByName(sessions);
  for (i = 0; i < entries.length; i += 1) {
    if (!map[entries[i].name]) {
      map[entries[i].name] = {
        name: entries[i].name,
        score: 0,
        checks: 0,
        textCount: 0
      };
    }
    map[entries[i].name].score += entries[i].score || 0;
    map[entries[i].name].checks += entries[i].checks || 0;
    map[entries[i].name].textCount += 1;
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      map[i].sessionCount = sessionMap[i] || 0;
      rows.push(map[i]);
    }
  }
  rows.sort(function (left, right) {
    if (right.score !== left.score) {
      return right.score - left.score;
    }
    return left.checks - right.checks;
  });
  return rows;
}

function countSessionsByName(sessions) {
  var map = {};
  var seen = {};
  var i;
  var key;
  for (i = 0; i < sessions.length; i += 1) {
    key = sessions[i].name + "|" + sessions[i].sessionId;
    if (!seen[key]) {
      seen[key] = true;
      map[sessions[i].name] = (map[sessions[i].name] || 0) + 1;
    }
  }
  return map;
}

function renderHighscores() {
  getHighscores(function (highscores) {
    var playerRows = buildPlayerSummaryRows(highscores, []);
    renderHighscoreList(highscoreList, playerRows);
    if (trainerHighscoreList) {
      renderHighscoreList(trainerHighscoreList, playerRows);
    }
    if (teacherUnlocked) {
      renderTeacherContent(highscores);
    }
  });
}

function renderHighscoreList(target, playerRows) {
  var i;
  target.innerHTML = "";
  if (!playerRows.length) {
    var item = document.createElement("li");
    item.textContent = "Noch keine Einträge vorhanden.";
    target.appendChild(item);
    return;
  }
  for (i = 0; i < playerRows.length && i < 10; i += 1) {
    var row = document.createElement("li");
    row.textContent = String(i + 1) + ". " + playerRows[i].name + " - " + String(playerRows[i].score) + " Punkte - " + String(playerRows[i].textCount) + " Sätze";
    target.appendChild(row);
  }
}

function saveCompletedTextHighscore() {
  if (state.savedTextEntries[state.sessionPointer]) {
    return;
  }
  state.savedTextEntries[state.sessionPointer] = true;
}

function initializeFirebase() {
  try {
    if (!window.firebase || !window.firebaseConfig) {
      return;
    }
    if (!isFirebaseConfigComplete(window.firebaseConfig)) {
      return;
    }
    if (!window.firebase.apps || !window.firebase.apps.length) {
      window.firebase.initializeApp(window.firebaseConfig);
    }
    firebaseDatabase = window.firebase.database();
    firebaseEnabled = true;
  } catch (error) {
    firebaseEnabled = false;
    firebaseDatabase = null;
  }
}

function isFirebaseConfigComplete(config) {
  return !!(
    config &&
    config.apiKey &&
    config.authDomain &&
    config.databaseURL &&
    config.projectId &&
    config.storageBucket &&
    config.messagingSenderId &&
    config.appId
  );
}

function getHighscores(callback) {
  if (firebaseEnabled && firebaseDatabase) {
    firebaseDatabase.ref(HIGHSCORE_PATH).once("value").then(function (snapshot) {
      var value;
      var list;
      var key;
      if (!snapshot.exists()) {
        callback(getLocalHighscores());
        return;
      }
      value = snapshot.val();
      list = [];
      for (key in value) {
        if (Object.prototype.hasOwnProperty.call(value, key)) {
          if (!value[key].entryId) {
            value[key].entryId = key;
          }
          value[key]._firebaseKey = key;
          list.push(value[key]);
        }
      }
      callback(mergeHighscoreEntries(list, getLocalHighscores()));
    }).catch(function () {
      callback(getLocalHighscores());
    });
    return;
  }
  callback(getLocalHighscores());
}

function saveHighscoreEntry(entry) {
  var highscores = getLocalHighscores();
  highscores.push(entry);
  localStorage.setItem(HIGHSCORE_STORAGE_KEY, JSON.stringify(highscores));

  if (firebaseEnabled && firebaseDatabase) {
    firebaseDatabase.ref(HIGHSCORE_PATH).push(entry).catch(function () {
    });
  }
}

function saveSessionStart(sessionEntry) {
  var sessions = getLocalSessions();
  sessions.push(sessionEntry);
  localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(sessions));
  if (firebaseEnabled && firebaseDatabase) {
    firebaseDatabase.ref(SESSION_PATH).push(sessionEntry).catch(function () {
    });
  }
}

function getSessionRecords(callback) {
  if (firebaseEnabled && firebaseDatabase) {
    firebaseDatabase.ref(SESSION_PATH).once("value").then(function (snapshot) {
      var value;
      var list;
      var key;
      if (!snapshot.exists()) {
        callback(getLocalSessions());
        return;
      }
      value = snapshot.val();
      list = [];
      for (key in value) {
        if (Object.prototype.hasOwnProperty.call(value, key)) {
          value[key]._firebaseKey = key;
          list.push(value[key]);
        }
      }
      callback(mergeSessionEntries(list, getLocalSessions()));
    }).catch(function () {
      callback(getLocalSessions());
    });
    return;
  }
  callback(getLocalSessions());
}

function mergeHighscoreEntries(primaryEntries, secondaryEntries) {
  var merged = [];
  var seen = {};
  var sources = [primaryEntries || [], secondaryEntries || []];
  var sourceIndex;
  var entryIndex;
  var entry;
  var key;
  for (sourceIndex = 0; sourceIndex < sources.length; sourceIndex += 1) {
    for (entryIndex = 0; entryIndex < sources[sourceIndex].length; entryIndex += 1) {
      entry = sources[sourceIndex][entryIndex];
      key = entry.entryId || [entry.name, entry.textTitle, entry.playedAt, entry.score].join("|");
      if (!seen[key]) {
        seen[key] = true;
        merged.push(entry);
      }
    }
  }
  return merged;
}

function mergeSessionEntries(primaryEntries, secondaryEntries) {
  var merged = [];
  var seen = {};
  var sources = [primaryEntries || [], secondaryEntries || []];
  var sourceIndex;
  var entryIndex;
  var entry;
  var key;
  for (sourceIndex = 0; sourceIndex < sources.length; sourceIndex += 1) {
    for (entryIndex = 0; entryIndex < sources[sourceIndex].length; entryIndex += 1) {
      entry = sources[sourceIndex][entryIndex];
      key = entry.sessionId || [entry.name, entry.startedAt].join("|");
      if (!seen[key]) {
        seen[key] = true;
        merged.push(entry);
      }
    }
  }
  return merged;
}

function copyWordStats(entries) {
  var list = [];
  var i;
  for (i = 0; i < entries.length; i += 1) {
    list.push({
      key: entries[i].key,
      word: entries[i].word,
      source: entries[i].source,
      entered: entries[i].entered
    });
  }
  return list;
}

function collectEditedInputStats(sentenceIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var expected = getExpectedSentenceTokens(sentence);
  var current = state.currentTokens[sentenceIndex];
  var tokenIndex;
  for (tokenIndex = 0; tokenIndex < current.length; tokenIndex += 1) {
    if (PUNCTUATION[current[tokenIndex].original]) {
      continue;
    }
    if (current[tokenIndex].value === current[tokenIndex].original) {
      continue;
    }
    if (current[tokenIndex].value === expected[tokenIndex]) {
      state.currentEditedCorrectInputs += 1;
    } else {
      state.currentEditedWrongInputs += 1;
    }
  }
}

function collectSentenceMistakes(sentenceIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var expected = getExpectedSentenceTokens(sentence);
  var current = state.currentTokens[sentenceIndex];
  var tokenIndex;
  for (tokenIndex = 0; tokenIndex < current.length; tokenIndex += 1) {
    if (PUNCTUATION[current[tokenIndex].original]) {
      continue;
    }
    if (current[tokenIndex].value === expected[tokenIndex]) {
      continue;
    }
    if (current[tokenIndex].value !== current[tokenIndex].original) {
      rememberWordStat(state.currentWrongEditedWords, {
        key: "edited-" + String(sentenceIndex) + "-" + String(tokenIndex),
        word: expected[tokenIndex],
        source: current[tokenIndex].original,
        entered: current[tokenIndex].value
      });
    } else {
      rememberWordStat(state.currentUneditedWrongWords, {
        key: "missed-" + String(sentenceIndex) + "-" + String(tokenIndex),
        word: expected[tokenIndex],
        source: current[tokenIndex].original,
        entered: current[tokenIndex].value
      });
    }
  }
}

function rememberWordStat(target, entry) {
  var i;
  for (i = 0; i < target.length; i += 1) {
    if (target[i].key === entry.key) {
      return;
    }
  }
  target.push(entry);
}

function getCurrentText() {
  return TEXTS[state.sessionOrder[state.sessionPointer]];
}

function getSentenceStatusText(sentenceIndex) {
  if (!state.checkedSentences[sentenceIndex]) {
    return "Noch nicht überprüft";
  }
  if (sentenceIsCorrect(sentenceIndex)) {
    return "Richtig überprüft";
  }
  if (state.revealedSolutions[sentenceIndex]) {
    return "Lösung sichtbar";
  }
  return "Noch nicht richtig (" + String(state.sentenceAttempts[sentenceIndex]) + "/3)";
}

function getSentenceStatusClass(sentenceIndex) {
  if (!state.checkedSentences[sentenceIndex]) {
    return "is-pending";
  }
  return sentenceIsCorrect(sentenceIndex) ? "is-correct" : "is-wrong";
}

function joinTokens(tokens) {
  var output = "";
  var i;
  for (i = 0; i < tokens.length; i += 1) {
    if (!output) {
      output = tokens[i];
    } else if (PUNCTUATION[tokens[i]]) {
      output += tokens[i];
    } else {
      output += " " + tokens[i];
    }
  }
  return output;
}

function shuffleArray(items) {
  var clone = items.slice();
  var i;
  var j;
  var temp;
  for (i = clone.length - 1; i > 0; i -= 1) {
    j = Math.floor(Math.random() * (i + 1));
    temp = clone[i];
    clone[i] = clone[j];
    clone[j] = temp;
  }
  return clone;
}

function seededShuffle(items, seed) {
  var clone = items.slice();
  var i;
  var j;
  var temp;
  var stateSeed = seed;
  for (i = clone.length - 1; i > 0; i -= 1) {
    stateSeed = nextSeed(stateSeed);
    j = stateSeed % (i + 1);
    temp = clone[i];
    clone[i] = clone[j];
    clone[j] = temp;
  }
  return clone;
}

function createSeedFromName(name) {
  var value = String(name || "").toLowerCase();
  var hash = 0;
  var i;
  for (i = 0; i < value.length; i += 1) {
    hash = (hash * 31 + value.charCodeAt(i)) % 2147483647;
  }
  if (!hash) {
    hash = 1234567;
  }
  return hash;
}

function nextSeed(seed) {
  return (seed * 48271) % 2147483647;
}

function applyPackageColors() {
  var palette = PACKAGE_COLORS[state.sessionPointer % PACKAGE_COLORS.length];
  document.body.style.setProperty("--package-accent", palette.accent);
  document.body.style.setProperty("--package-accent-strong", palette.strong);
  document.body.style.setProperty("--package-accent-soft", palette.soft);
}

function getCurrentTextScore() {
  var sum = 0;
  var i;
  for (i = 0; i < state.sentenceScores.length; i += 1) {
    sum += state.sentenceScores[i];
  }
  return sum;
}

function createEntryId() {
  return "entry-" + String(new Date().getTime()) + "-" + String(Math.floor(Math.random() * 100000));
}

function getTeacherPassword() {
  return localStorage.getItem(TEACHER_PASSWORD_KEY) || DEFAULT_TEACHER_PASSWORD;
}

function openTeacherDialog() {
  teacherError.textContent = "";
  updateTeacherSections();
  if (typeof teacherDialog.showModal === "function") {
    teacherDialog.showModal();
  } else {
    teacherDialog.setAttribute("open", "true");
  }
}

function updateTeacherSections() {
  if (teacherUnlocked) {
    teacherLoginSection.className = "teacher-section is-hidden";
    teacherContentSection.className = "teacher-section";
    renderHighscores();
  } else {
    teacherLoginSection.className = "teacher-section";
    teacherContentSection.className = "teacher-section is-hidden";
  }
}

function unlockTeacherArea() {
  if (teacherPasswordInput.value === getTeacherPassword()) {
    teacherUnlocked = true;
    teacherError.textContent = "";
    teacherPasswordInput.value = "";
    updateTeacherSections();
    return;
  }
  teacherError.textContent = "Das Passwort stimmt noch nicht.";
}

function lockTeacherArea() {
  teacherUnlocked = false;
  teacherError.textContent = "";
  updateTeacherSections();
}

function saveTeacherPassword() {
  var newPassword = teacherNewPasswordInput.value.replace(/^\s+|\s+$/g, "");
  if (!newPassword) {
    teacherError.textContent = "Bitte ein neues Passwort eingeben.";
    return;
  }
  localStorage.setItem(TEACHER_PASSWORD_KEY, newPassword);
  teacherNewPasswordInput.value = "";
  teacherError.textContent = "Das Lehrerpasswort wurde gespeichert.";
}

function resetAllTeacherStats() {
  if (!window.confirm("Sollen wirklich alle Highscores, Sitzungen und Statistikdaten gelöscht werden?")) {
    return;
  }
  localStorage.setItem(HIGHSCORE_STORAGE_KEY, JSON.stringify([]));
  localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify([]));
  teacherError.textContent = "Alle Statistikdaten wurden zurückgesetzt.";
  deleteAllRemoteStatistics(function () {
    renderHighscores();
  });
}

function renderTeacherContent(highscores) {
  renderTeacherHighscoreList(highscores);
  renderTeacherStats(highscores);
}

function renderTeacherHighscoreList(highscores) {
  var i;
  teacherHighscoreList.innerHTML = "";
  if (!highscores.length) {
    teacherHighscoreList.textContent = "Noch keine Einträge vorhanden.";
    return;
  }
  for (i = 0; i < highscores.length; i += 1) {
    teacherHighscoreList.appendChild(createTeacherHighscoreRow(highscores[i]));
  }
}

function createTeacherHighscoreRow(entry) {
  var row = document.createElement("div");
  var copy = document.createElement("div");
  var button = document.createElement("button");
  row.className = "teacher-highscore-row";
  copy.className = "teacher-row-copy";
  copy.textContent = entry.name + " - " + entry.textTitle + " - " + String(entry.score) + " Punkte - " + String(entry.checks) + " Kontrollen";
  button.className = "teacher-delete-button button-secondary";
  button.type = "button";
  button.textContent = "Löschen";
  button.onclick = function () {
    deleteHighscoreEntry(entry);
  };
  row.appendChild(copy);
  row.appendChild(button);
  return row;
}

function deleteHighscoreEntry(entry) {
  var localEntries = getLocalHighscores();
  var filtered = [];
  var i;
  for (i = 0; i < localEntries.length; i += 1) {
    if (localEntries[i].entryId !== entry.entryId) {
      filtered.push(localEntries[i]);
    }
  }
  localStorage.setItem(HIGHSCORE_STORAGE_KEY, JSON.stringify(filtered));
  if (firebaseEnabled && firebaseDatabase && entry._firebaseKey) {
    firebaseDatabase.ref(HIGHSCORE_PATH + "/" + entry._firebaseKey).remove().then(function () {
      renderHighscores();
    }).catch(function () {
      renderHighscores();
    });
    return;
  }
  renderHighscores();
}

function renderTeacherStats(highscores) {
  renderPlayerStats(highscores);
  renderTextStats(highscores);
  renderEditedWordStats(highscores);
  renderMissedWordStats(highscores);
}

function renderPlayerStats(highscores) {
  var map = {};
  var rows = [];
  var i;
  teacherStatsPlayers.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    if (!map[highscores[i].name]) {
      map[highscores[i].name] = { name: highscores[i].name, score: 0, entries: 0 };
    }
    map[highscores[i].name].score += highscores[i].score;
    map[highscores[i].name].entries += 1;
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push(map[i]);
    }
  }
  rows.sort(function (left, right) {
    return right.score - left.score;
  });
  if (!rows.length) {
    teacherStatsPlayers.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  for (i = 0; i < rows.length && i < 10; i += 1) {
    teacherStatsPlayers.appendChild(createStatRow(rows[i].name, String(rows[i].score) + " Punkte in " + String(rows[i].entries) + " Texten"));
  }
}

function renderTextStats(highscores) {
  var map = {};
  var rows = [];
  var i;
  teacherStatsTexts.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    if (!map[highscores[i].textTitle]) {
      map[highscores[i].textTitle] = { title: highscores[i].textTitle, score: 0, checks: 0, entries: 0 };
    }
    map[highscores[i].textTitle].score += highscores[i].score;
    map[highscores[i].textTitle].checks += highscores[i].checks;
    map[highscores[i].textTitle].entries += 1;
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push(map[i]);
    }
  }
  rows.sort(function (left, right) {
    return right.entries - left.entries;
  });
  if (!rows.length) {
    teacherStatsTexts.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  for (i = 0; i < rows.length && i < 10; i += 1) {
    teacherStatsTexts.appendChild(
      createStatRow(
        rows[i].title,
        "Ø " + String(Math.round((rows[i].score / rows[i].entries) * 10) / 10) + " Punkte, Ø " + String(Math.round((rows[i].checks / rows[i].entries) * 10) / 10) + " Kontrollen"
      )
    );
  }
}

function renderEditedWordStats(highscores) {
  renderWordStatsList(teacherStatsEditedWords, highscores, "wrongEditedWords", true);
}

function renderMissedWordStats(highscores) {
  renderWordStatsList(teacherStatsMissedWords, highscores, "untouchedWrongWords", false);
}

function renderWordStatsList(target, highscores, propertyName, showEnteredWord) {
  var map = {};
  var rows = [];
  var i;
  var j;
  var list;
  target.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    list = highscores[i][propertyName] || [];
    for (j = 0; j < list.length; j += 1) {
      addWordStat(map, list[j], showEnteredWord);
    }
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push(map[i]);
    }
  }
  rows.sort(function (left, right) {
    return right.count - left.count;
  });
  if (!rows.length) {
    target.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  for (i = 0; i < rows.length && i < 20; i += 1) {
    target.appendChild(createStatRow(rows[i].word, buildWordStatValue(rows[i], showEnteredWord)));
  }
}

function addWordStat(map, entry, showEnteredWord) {
  var key = entry.word || "unbekannt";
  if (!map[key]) {
    map[key] = { word: key, count: 0, source: entry.source || "", examples: [] };
  }
  map[key].count += 1;
  if (showEnteredWord && entry.entered) {
    rememberExample(map[key].examples, entry.entered);
  }
}

function rememberExample(examples, value) {
  var i;
  for (i = 0; i < examples.length; i += 1) {
    if (examples[i] === value) {
      return;
    }
  }
  if (examples.length < 3) {
    examples.push(value);
  }
}

function buildWordStatValue(entry, showEnteredWord) {
  var value = String(entry.count) + "x";
  if (showEnteredWord && entry.examples.length) {
    value += ", oft geschrieben als: " + entry.examples.join(", ");
    return value;
  }
  if (entry.source) {
    value += ", oft stehen geblieben als: " + entry.source;
  }
  return value;
}

function createStatRow(label, value) {
  var row = document.createElement("div");
  var left = document.createElement("div");
  var right = document.createElement("div");
  row.className = "teacher-stat-row";
  left.className = "teacher-row-copy";
  right.className = "teacher-row-copy";
  left.textContent = label;
  right.textContent = value;
  row.appendChild(left);
  row.appendChild(right);
  return row;
}

function renderTeacherContent(highscores) {
  getSessionRecords(function (sessions) {
    renderTeacherHighscoreList(highscores, sessions);
    renderTeacherStats(highscores, sessions);
  });
}

function renderTeacherHighscoreList(highscores, sessions) {
  var rows = buildTeacherHighscoreRows(highscores, sessions);
  teacherHighscoreList.innerHTML = "";
  if (!rows.length) {
    teacherHighscoreList.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  teacherHighscoreList.appendChild(createTeacherTable(
    ["Name des Schülers", "Punkte", "Zeit der Bearbeitung", "Quote der richtigen Eingaben in %", "Anzahl der Sitzungen", "Aktion"],
    rows
  ));
}

function renderTeacherStats(highscores, sessions) {
  renderTextStats(highscores);
  renderEditedWordStats(highscores);
  renderMissedWordStats(highscores);
  renderPlayerStats(highscores, sessions);
}

function renderPlayerStats(highscores, sessions) {
  var map = {};
  var sessionMap = countSessionsByName(sessions);
  var rows = [];
  var i;
  teacherStatsPlayers.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    if (!map[highscores[i].name]) {
      map[highscores[i].name] = { name: highscores[i].name, texts: {} };
    }
    map[highscores[i].name].texts[highscores[i].textTitle] = true;
  }
  for (i in sessionMap) {
    if (Object.prototype.hasOwnProperty.call(sessionMap, i) && !map[i]) {
      map[i] = { name: i, texts: {} };
    }
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push([
        map[i].name,
        String(sessionMap[i] || 0),
        Object.keys(map[i].texts).sort().join(", ") || "-"
      ]);
    }
  }
  rows.sort(function (left, right) {
    return left[0] < right[0] ? -1 : 1;
  });
  if (!rows.length) {
    teacherStatsPlayers.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  teacherStatsPlayers.appendChild(createTeacherTable(
    ["Name", "Sitzungen", "Bearbeitete Texte"],
    rows
  ));
}

function renderTextStats(highscores) {
  var map = {};
  var rows = [];
  var i;
  teacherStatsTexts.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    if (!map[highscores[i].textTitle]) {
      map[highscores[i].textTitle] = { title: highscores[i].textTitle, score: 0, checks: 0, entries: 0 };
    }
    map[highscores[i].textTitle].score += highscores[i].score || 0;
    map[highscores[i].textTitle].checks += highscores[i].checks || 0;
    map[highscores[i].textTitle].entries += 1;
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push([
        map[i].title,
        String(map[i].entries),
        formatNumber(map[i].score / map[i].entries),
        formatNumber(map[i].checks / map[i].entries)
      ]);
    }
  }
  rows.sort(function (left, right) {
    return Number(right[1]) - Number(left[1]);
  });
  if (!rows.length) {
    teacherStatsTexts.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  teacherStatsTexts.appendChild(createTeacherTable(
    ["Text", "Bearbeitungen", "Ø Punkte", "Ø Kontrollen"],
    rows
  ));
}

function renderEditedWordStats(highscores) {
  renderWordStatsTable(teacherStatsEditedWords, highscores, "wrongEditedWords", true);
}

function renderMissedWordStats(highscores) {
  renderWordStatsTable(teacherStatsMissedWords, highscores, "untouchedWrongWords", false);
}

function renderWordStatsTable(target, highscores, propertyName, showEnteredWord) {
  var map = {};
  var rows = [];
  var i;
  var j;
  var list;
  target.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    list = highscores[i][propertyName] || [];
    for (j = 0; j < list.length; j += 1) {
      addWordStatToTable(map, list[j], highscores[i].name, showEnteredWord);
    }
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push(buildWordTableRow(map[i], showEnteredWord));
    }
  }
  rows.sort(function (left, right) {
    return Number(right[1]) - Number(left[1]);
  });
  if (!rows.length) {
    target.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  target.appendChild(createTeacherTable(
    showEnteredWord
      ? ["Zielwort", "Fehlerzahl", "Oft geschrieben als", "Nutzer"]
      : ["Zielwort", "Fehlerzahl", "Standen geblieben als", "Nutzer"],
    rows
  ));
}

function addWordStatToTable(map, entry, userName, showEnteredWord) {
  var key = entry.word || "unbekannt";
  if (!map[key]) {
    map[key] = { word: key, count: 0, source: entry.source || "", examples: [], users: [] };
  }
  map[key].count += 1;
  rememberExample(map[key].users, userName);
  if (showEnteredWord && entry.entered) {
    rememberExample(map[key].examples, entry.entered);
  }
}

function buildWordTableRow(entry, showEnteredWord) {
  return [
    entry.word,
    String(entry.count),
    showEnteredWord ? entry.examples.join(", ") : entry.source,
    entry.users.join(", ")
  ];
}

function buildTeacherHighscoreRows(highscores, sessions) {
  var summaries = buildPlayerSummaryRows(highscores, sessions);
  var rows = [];
  var i;
  for (i = 0; i < summaries.length; i += 1) {
    rows.push([
      summaries[i].name,
      String(summaries[i].score),
      formatTimestamp(summaries[i].lastPlayedAt),
      summaries[i].inputRate,
      String(summaries[i].sessionCount || 0),
      createDeleteButton(summaries[i].name)
    ]);
  }
  return rows;
}

function buildPlayerSummaryRows(entries, sessions) {
  var map = {};
  var rows = [];
  var i;
  var sessionMap = countSessionsByName(sessions);
  for (i = 0; i < entries.length; i += 1) {
    if (!map[entries[i].name]) {
      map[entries[i].name] = {
        name: entries[i].name,
        score: 0,
        checks: 0,
        textCount: 0,
        editedCorrectInputs: 0,
        editedWrongInputs: 0,
        lastPlayedAt: ""
      };
    }
    map[entries[i].name].score += entries[i].score || 0;
    map[entries[i].name].checks += entries[i].checks || 0;
    map[entries[i].name].textCount += 1;
    map[entries[i].name].editedCorrectInputs += entries[i].editedCorrectInputs || 0;
    map[entries[i].name].editedWrongInputs += entries[i].editedWrongInputs || 0;
    if (!map[entries[i].name].lastPlayedAt || entries[i].playedAt > map[entries[i].name].lastPlayedAt) {
      map[entries[i].name].lastPlayedAt = entries[i].playedAt || "";
    }
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      map[i].sessionCount = sessionMap[i] || 0;
      map[i].inputRate = calculateInputRate(map[i].editedCorrectInputs, map[i].editedWrongInputs);
      rows.push(map[i]);
    }
  }
  rows.sort(function (left, right) {
    if (right.score !== left.score) {
      return right.score - left.score;
    }
    return left.checks - right.checks;
  });
  return rows;
}

function calculateInputRate(correctInputs, wrongInputs) {
  var total = correctInputs + wrongInputs;
  if (!total) {
    return "-";
  }
  return formatNumber((correctInputs / total) * 100) + " %";
}

function formatNumber(value) {
  return String(Math.round(value * 10) / 10);
}

function formatTimestamp(value) {
  var date;
  if (!value) {
    return "-";
  }
  date = new Date(value);
  if (isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString("de-DE");
}

function createTeacherTable(headers, rows) {
  var table = document.createElement("table");
  var thead = document.createElement("thead");
  var tbody = document.createElement("tbody");
  var headRow = document.createElement("tr");
  var i;
  var j;
  table.className = "teacher-table";
  for (i = 0; i < headers.length; i += 1) {
    var th = document.createElement("th");
    th.textContent = headers[i];
    headRow.appendChild(th);
  }
  thead.appendChild(headRow);
  table.appendChild(thead);
  for (i = 0; i < rows.length; i += 1) {
    var bodyRow = document.createElement("tr");
    for (j = 0; j < rows[i].length; j += 1) {
      var td = document.createElement("td");
      if (typeof rows[i][j] === "string") {
        td.textContent = rows[i][j];
      } else if (rows[i][j] && rows[i][j].nodeType) {
        td.appendChild(rows[i][j]);
      }
      bodyRow.appendChild(td);
    }
    tbody.appendChild(bodyRow);
  }
  table.appendChild(tbody);
  return table;
}

function exportTeacherTable(container, fileBaseName) {
  var tableData = collectTeacherTableData(container);
  if (!tableData) {
    teacherError.textContent = "Für diesen Bereich gibt es gerade keine Tabelle zum Export.";
    return;
  }
  teacherError.textContent = "Export wurde vorbereitet.";
  downloadTeacherCsv(tableData, fileBaseName);
}

function collectTeacherTableData(container) {
  var table = container ? container.querySelector("table") : null;
  var headers = [];
  var rows = [];
  var rowNodes;
  var i;
  var j;
  if (!table) {
    return null;
  }
  rowNodes = table.querySelectorAll("tr");
  if (!rowNodes.length) {
    return null;
  }
  for (i = 0; i < rowNodes[0].children.length; i += 1) {
    headers.push(cleanExportValue(rowNodes[0].children[i].textContent));
  }
  for (i = 1; i < rowNodes.length; i += 1) {
    var currentRow = [];
    for (j = 0; j < rowNodes[i].children.length; j += 1) {
      currentRow.push(cleanExportValue(rowNodes[i].children[j].textContent));
    }
    rows.push(currentRow);
  }
  return { headers: headers, rows: rows };
}

function cleanExportValue(value) {
  return String(value || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
}

function downloadTeacherCsv(tableData, fileBaseName) {
  var lines = [];
  var i;
  var blob;
  lines.push(buildCsvRow(tableData.headers));
  for (i = 0; i < tableData.rows.length; i += 1) {
    lines.push(buildCsvRow(tableData.rows[i]));
  }
  blob = new Blob(["\ufeff" + lines.join("\r\n")], { type: "text/csv;charset=utf-8;" });
  triggerDownload(blob, sanitizeExportFileName(fileBaseName) + ".csv");
}

function buildCsvRow(values) {
  var parts = [];
  var i;
  for (i = 0; i < values.length; i += 1) {
    parts.push("\"" + String(values[i] || "").replace(/"/g, "\"\"") + "\"");
  }
  return parts.join(";");
}

function sanitizeExportFileName(value) {
  return String(value || "export").replace(/[^a-z0-9_-]+/gi, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
}

function triggerDownload(blob, fileName) {
  var url = window.URL.createObjectURL(blob);
  var link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.setTimeout(function () {
    window.URL.revokeObjectURL(url);
  }, 0);
}

function createDeleteButton(playerName) {
  var button = document.createElement("button");
  button.className = "teacher-delete-button button-secondary";
  button.type = "button";
  button.textContent = "Löschen";
  button.onclick = function () {
    deletePlayerData(playerName);
  };
  return button;
}

function deletePlayerData(playerName) {
  var localEntries = getLocalHighscores();
  var localSessions = getLocalSessions();
  var filteredEntries = [];
  var filteredSessions = [];
  var i;
  for (i = 0; i < localEntries.length; i += 1) {
    if (localEntries[i].name !== playerName) {
      filteredEntries.push(localEntries[i]);
    }
  }
  for (i = 0; i < localSessions.length; i += 1) {
    if (localSessions[i].name !== playerName) {
      filteredSessions.push(localSessions[i]);
    }
  }
  localStorage.setItem(HIGHSCORE_STORAGE_KEY, JSON.stringify(filteredEntries));
  localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(filteredSessions));
  deleteRemotePlayerData(playerName, function () {
    renderHighscores();
  });
}

function deleteRemotePlayerData(playerName, callback) {
  var pending = 0;
  if (!firebaseEnabled || !firebaseDatabase) {
    callback();
    return;
  }
  pending = 2;
  firebaseDatabase.ref(HIGHSCORE_PATH).once("value").then(function (snapshot) {
    deleteMatchingSnapshotChildren(snapshot, HIGHSCORE_PATH, playerName, doneDeleting);
  }).catch(doneDeleting);
  firebaseDatabase.ref(SESSION_PATH).once("value").then(function (snapshot) {
    deleteMatchingSnapshotChildren(snapshot, SESSION_PATH, playerName, doneDeleting);
  }).catch(doneDeleting);

  function doneDeleting() {
    pending -= 1;
    if (pending <= 0) {
      callback();
    }
  }
}

function deleteAllRemoteStatistics(callback) {
  var pending = 0;
  function doneDeleting() {
    pending -= 1;
    if (pending <= 0) {
      callback();
    }
  }
  if (!firebaseEnabled || !firebaseDatabase) {
    callback();
    return;
  }
  pending = 2;
  firebaseDatabase.ref(HIGHSCORE_PATH).remove().then(doneDeleting).catch(doneDeleting);
  firebaseDatabase.ref(SESSION_PATH).remove().then(doneDeleting).catch(doneDeleting);
}

function deleteMatchingSnapshotChildren(snapshot, basePath, playerName, callback) {
  var value;
  var key;
  var tasks = [];
  if (!snapshot.exists()) {
    callback();
    return;
  }
  value = snapshot.val();
  for (key in value) {
    if (Object.prototype.hasOwnProperty.call(value, key) && value[key].name === playerName) {
      tasks.push(firebaseDatabase.ref(basePath + "/" + key).remove());
    }
  }
  if (!tasks.length) {
    callback();
    return;
  }
  Promise.all(tasks).then(callback).catch(callback);
}

function normalizeGermanText(value) {
  var output = String(value);
  var replacements = [
    [/\bNoe\b/g, "__NAME_NOE__"],
    [/\bZoe\b/g, "__NAME_ZOE__"],
    [/gruuenen/g, "gr\u00fcnen"],
    [/gruuenem/g, "gr\u00fcnem"],
    [/gruuenes/g, "gr\u00fcnes"],
    [/gruuen/g, "gr\u00fcn"],
    [/Fuelleder/g, "F\u00fcller"]
  ];
  var wordFixes = [
    [/\bStrasse\b/g, "Stra\u00dfe"],
    [/\bStrassenbahn\b/g, "Stra\u00dfenbahn"],
    [/\bSchulstrasse\b/g, "Schulstra\u00dfe"],
    [/\bgrosse\b/g, "gro\u00dfe"],
    [/\bgrossen\b/g, "gro\u00dfen"],
    [/\bgrosser\b/g, "gro\u00dfer"],
    [/\bgrosses\b/g, "gro\u00dfes"],
    [/\bGrosse\b/g, "Gro\u00dfe"],
    [/\bGrossen\b/g, "Gro\u00dfen"],
    [/\bGrosser\b/g, "Gro\u00dfer"],
    [/\bGrosses\b/g, "Gro\u00dfes"],
    [/\bheisst\b/g, "hei\u00dft"],
    [/\bweisse\b/g, "wei\u00dfe"],
    [/\bWeisse\b/g, "Wei\u00dfe"],
    [/\bFussball\b/g, "Fu\u00dfball"],
    [/\bFuss\b/g, "Fu\u00df"],
    [/\bWoerterbuch\b/g, "W\u00f6rterbuch"],
    [/\bUeberraschungsbuch\b/g, "\u00dcberraschungsbuch"],
    [/\bUeberraschung\b/g, "\u00dcberraschung"],
    [/\bOeff/g, "\u00d6ff"],
    [/\boeff/g, "\u00f6ff"]
  ];
  var i;
  for (i = 0; i < replacements.length; i += 1) {
    output = output.replace(replacements[i][0], replacements[i][1]);
  }
  for (i = 0; i < wordFixes.length; i += 1) {
    output = output.replace(wordFixes[i][0], wordFixes[i][1]);
  }
  output = output.replace(/gruesst/g, "gr\u00fc\u00dft");
  output = output.replace(/Zahnraeder/g, "Zahnr\u00e4der");
  output = output.replace(/__NAME_NOE__/g, "Noe");
  output = output.replace(/__NAME_ZOE__/g, "Zoe");
  return output;
}

function getThemeClipartsForText(text) {
  var defaults = {
    school: ["🏫", "🎒", "📚", "✏️"],
    garden: ["🌱", "🌼", "🥕", "💧"],
    playground: ["⚽", "🏃", "🎯", "🧩"],
    family: ["🏠", "🍲", "🧸", "🎵"],
    reading: ["📖", "📚", "🔎", "📝"],
    swim: ["🏊", "⏱️", "💦", "🏅"],
    zoo: ["🐘", "🐧", "🐠", "🐼"],
    birthday: ["🎂", "🎁", "🎈", "🎉"],
    music: ["🎵", "🥁", "🎺", "🎤"],
    camp: ["⛺", "🔥", "🌅", "📚"]
  };
  return defaults[text.theme] ? defaults[text.theme].slice() : ["📌", "💡", "📘", "✨"];
}

function renderThemeStage(text) {
  var cliparts = getThemeClipartsForText(text);
  var i;
  clipartList.innerHTML = "";
  for (i = 0; i < cliparts.length; i += 1) {
    var item = document.createElement("div");
    var emoji = document.createElement("span");
    item.className = "clipart-chip";
    item.style.setProperty("--twist", i % 2 === 0 ? "-4" : "4");
    emoji.className = "clipart-chip__emoji";
    emoji.textContent = cliparts[i];
    item.appendChild(emoji);
    clipartList.appendChild(item);
  }
}

function renderSentenceCard(text, sentenceIndex) {
  var sentence = text.sentences[sentenceIndex];
  var sentenceCard = document.createElement("article");
  var sentenceHead = document.createElement("div");
  var sentenceLabel = document.createElement("p");
  var sentenceHeadRight = document.createElement("div");
  var sentenceState = document.createElement("button");
  var sentenceClipartChip = document.createElement("div");
  var sentenceClipartEmoji = document.createElement("span");
  var wordsRow = document.createElement("div");
  var cliparts = getThemeClipartsForText(text);
  var i;

  sentenceCard.className = "sentence-card";
  sentenceCard.setAttribute("data-theme", text.theme);
  if (state.checkedSentences[sentenceIndex]) {
    sentenceCard.className += sentenceIsCorrect(sentenceIndex) ? " is-correct" : " has-errors";
  }

  sentenceHead.className = "sentence-card__head";
  sentenceLabel.className = "sentence-label";
  sentenceLabel.textContent = "Satz " + String(sentenceIndex + 1);

  sentenceState.className = "sentence-state " + getSentenceStatusClass(sentenceIndex);
  sentenceState.type = "button";
  sentenceState.textContent = getSentenceStatusText(sentenceIndex);
  sentenceState.onclick = createCheckHandler(sentenceIndex);

  sentenceClipartChip.className = "sentence-clipart";
  sentenceClipartEmoji.className = "sentence-clipart__emoji";
  sentenceClipartEmoji.textContent = cliparts[sentenceIndex % cliparts.length];
  sentenceClipartChip.appendChild(sentenceClipartEmoji);

  sentenceHeadRight.className = "sentence-head-right";
  sentenceHeadRight.appendChild(sentenceState);
  sentenceHeadRight.appendChild(sentenceClipartChip);

  sentenceHead.appendChild(sentenceLabel);
  sentenceHead.appendChild(sentenceHeadRight);

  wordsRow.className = "sentence-card__words";
  for (i = 0; i < sentence.present.length; i += 1) {
    wordsRow.appendChild(createTokenElement(sentenceIndex, i));
  }

  sentenceCard.appendChild(sentenceHead);
  sentenceCard.appendChild(wordsRow);
  if (state.revealedSolutions[sentenceIndex]) {
    sentenceCard.appendChild(createSolutionBox(sentenceIndex));
  }
  sentenceList.appendChild(sentenceCard);
}

function createEditHandler(sentenceIndex, tokenIndex) {
  return function () {
    var tokenState = state.currentTokens[sentenceIndex][tokenIndex];
    var nextValue = window.prompt("Wort \u00e4ndern", tokenState.value);
    if (nextValue === null) {
      return;
    }
    nextValue = nextValue.replace(/^\s+|\s+$/g, "");
    state.currentTokens[sentenceIndex][tokenIndex].value = nextValue || tokenState.original;
    state.checkedSentences[sentenceIndex] = false;
    renderSentences();
  };
}

function createSolutionBox(sentenceIndex) {
  var solutionBox = document.createElement("div");
  var solutionLabel = document.createElement("strong");
  var solutionText = document.createElement("span");
  solutionBox.className = "solution-box";
  solutionLabel.textContent = "L\u00f6sung ab dem 3. Fehlversuch:";
  solutionText.textContent = "Verbform: " + getSentenceVerbSolutions(sentenceIndex).join(", ");
  solutionBox.appendChild(solutionLabel);
  solutionBox.appendChild(solutionText);
  return solutionBox;
}

function checkSentence(sentenceIndex) {
  var correct = sentenceIsCorrect(sentenceIndex);
  state.checkedSentences[sentenceIndex] = true;
  state.totalChecks += 1;
  state.textCheckCounts[state.sessionPointer] = (state.textCheckCounts[state.sessionPointer] || 0) + 1;
  collectEditedInputStats(sentenceIndex);
  attemptsOutput.textContent = String(state.totalChecks);
  if (correct) {
    awardSentencePoints(sentenceIndex);
    saveSentenceHighscore(sentenceIndex);
    renderSentences();
    scoreOutput.textContent = String(getCurrentTextScore());
    if (allSentencesCorrect() && allSentencesResolved()) {
      nextButton.disabled = false;
      saveCompletedTextHighscore();
      renderHighscores();
      feedbackBox.className = "feedback-box is-success";
      feedbackBox.textContent = "Super. Alle S\u00e4tze dieses Textes stimmen.";
    } else {
      feedbackBox.className = "feedback-box is-success";
      feedbackBox.textContent = "Satz " + String(sentenceIndex + 1) + " stimmt.";
    }
    return;
  }
  state.sentenceAttempts[sentenceIndex] += 1;
  collectSentenceMistakes(sentenceIndex);
  if (state.sentenceAttempts[sentenceIndex] >= 3) {
    state.revealedSolutions[sentenceIndex] = true;
  }
  renderSentences();
  feedbackBox.className = "feedback-box is-warning";
  feedbackBox.textContent = state.revealedSolutions[sentenceIndex]
    ? "Satz " + String(sentenceIndex + 1) + " ist zum 3. Mal noch nicht richtig. Die L\u00f6sung wird jetzt angezeigt."
    : "Satz " + String(sentenceIndex + 1) + " ist noch nicht richtig. Versuch " + String(state.sentenceAttempts[sentenceIndex]) + " von 3.";
}

function checkAllSentences() {
  var i;
  for (i = 0; i < getCurrentText().sentences.length; i += 1) {
    if (!sentenceIsCorrect(i)) {
      checkSentence(i);
    } else if (!state.checkedSentences[i]) {
      checkSentence(i);
    }
  }
  if (allSentencesCorrect() && allSentencesResolved()) {
    nextButton.disabled = false;
    saveCompletedTextHighscore();
    renderHighscores();
    feedbackBox.className = "feedback-box is-success";
    feedbackBox.textContent = "Alle S\u00e4tze wurden kontrolliert. Dieser Text ist fertig.";
  } else {
    feedbackBox.className = "feedback-box is-warning";
    feedbackBox.textContent = "Alle S\u00e4tze wurden kontrolliert. Schau dir die roten W\u00f6rter noch einmal an.";
  }
}

function renderTeacherHighscoreList(highscores, sessions) {
  var rows = buildTeacherHighscoreRows(highscores, sessions);
  teacherHighscoreList.innerHTML = "";
  if (!rows.length) {
    teacherHighscoreList.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  teacherHighscoreList.appendChild(createTeacherTable(
    ["Name des Sch\u00fclers", "Punkte", "Zeit der Bearbeitung", "Quote der richtigen Eingaben in %", "Anzahl der Sitzungen", "Aktion"],
    rows
  ));
}

function renderTextStats(highscores) {
  var map = {};
  var rows = [];
  var i;
  teacherStatsTexts.innerHTML = "";
  for (i = 0; i < highscores.length; i += 1) {
    if (!map[highscores[i].textTitle]) {
      map[highscores[i].textTitle] = { title: highscores[i].textTitle, score: 0, checks: 0, entries: 0 };
    }
    map[highscores[i].textTitle].score += highscores[i].score || 0;
    map[highscores[i].textTitle].checks += highscores[i].checks || 0;
    map[highscores[i].textTitle].entries += 1;
  }
  for (i in map) {
    if (Object.prototype.hasOwnProperty.call(map, i)) {
      rows.push([
        map[i].title,
        String(map[i].entries),
        formatNumber(map[i].score / map[i].entries),
        formatNumber(map[i].checks / map[i].entries)
      ]);
    }
  }
  rows.sort(function (left, right) {
    return Number(right[1]) - Number(left[1]);
  });
  if (!rows.length) {
    teacherStatsTexts.textContent = "Noch keine Daten vorhanden.";
    return;
  }
  teacherStatsTexts.appendChild(createTeacherTable(
    ["Text", "Bearbeitungen", "\u00d8 Punkte", "\u00d8 Kontrollen"],
    rows
  ));
}

function createDeleteButton(playerName) {
  var button = document.createElement("button");
  button.className = "teacher-delete-button button-secondary";
  button.type = "button";
  button.textContent = "L\u00f6schen";
  button.onclick = function () {
    deletePlayerData(playerName);
  };
  return button;
}

function polishTextLibrary(texts) {
  var polished = [];
  var textIndex;
  var sentenceIndex;
  var sentence;
  var present;
  var past;
  for (textIndex = 0; textIndex < texts.length; textIndex += 1) {
    for (sentenceIndex = 0; sentenceIndex < texts[textIndex].sentences.length; sentenceIndex += 1) {
      sentence = texts[textIndex].sentences[sentenceIndex];
      present = typeof sentence.present === "string" ? sentence.present : joinTokens(sentence.present);
      past = typeof sentence.past === "string" ? sentence.past : joinTokens(sentence.past);

      sentence.present = tokenizeSentence(present);
      sentence.past = tokenizeSentence(past);
      sentence.answer = buildVerbOnlyPastTokens(sentence.present, sentence.past);
    }
    polished.push(texts[textIndex]);
  }
  return polished;
}

function applyTextOverride(text) {
  var pairs = null;
  var title = text.title;
  if (title === "Fr\u00fchdienst im Klassenraum") {
    pairs = [
      ["Fr\u00fch am Morgen kommt Jana als Erste in den Klassenraum.", "Fr\u00fch am Morgen kam Jana als Erste in den Klassenraum."],
      ["Sie h\u00e4ngt ihre Jacke auf und stellt ihren Ranzen neben den Tisch.", "Sie h\u00e4ngte ihre Jacke auf und stellte ihren Ranzen neben den Tisch."],
      ["Dann wischt sie die Tafel sauber und r\u00fcckt die Kreide zurecht.", "Dann wischte sie die Tafel sauber und r\u00fcckte die Kreide zurecht."],
      ["Emil kommt dazu und legt den Wochenplan vorne auf das Pult.", "Emil kam dazu und legte den Wochenplan vorne auf das Pult."],
      ["Gemeinsam \u00f6ffnen beide die Fenster und lassen frische Luft herein.", "Gemeinsam \u00f6ffneten beide die Fenster und lie\u00dfen frische Luft herein."],
      ["Jana z\u00e4hlt die St\u00fchle nach und schiebt einen schiefen Tisch gerade.", "Jana z\u00e4hlte die St\u00fchle nach und schob einen schiefen Tisch gerade."],
      ["Emil entdeckt einen roten Stift auf dem Boden und legt ihn in die Kiste.", "Emil entdeckte einen roten Stift auf dem Boden und legte ihn in die Kiste."],
      ["Kurz vor dem Klingeln pr\u00fcfen beide noch einmal alles und l\u00e4cheln zufrieden.", "Kurz vor dem Klingeln pr\u00fcften beide noch einmal alles und l\u00e4chelten zufrieden."]
    ];
  } else if (title === "Das neue Matheheft") {
    pairs = [
      ["Mila schl\u00e4gt ihr neues Matheheft vorsichtig auf.", "Mila schlug ihr neues Matheheft vorsichtig auf."],
      ["Sie liest die erste Aufgabe und denkt kurz nach.", "Sie las die erste Aufgabe und dachte kurz nach."],
      ["Dann schreibt sie die Zahlen sauber in die K\u00e4stchen.", "Dann schrieb sie die Zahlen sauber in die K\u00e4stchen."],
      ["Tom schaut auf seine Seite und vergleicht seinen Rechenweg mit ihrem.", "Tom schaute auf seine Seite und verglich seinen Rechenweg mit ihrem."],
      ["Mila radiert eine kleine Stelle weg und beginnt die Aufgabe noch einmal.", "Mila radierte eine kleine Stelle weg und begann die Aufgabe noch einmal."],
      ["Danach findet sie die richtige L\u00f6sung und zeigt auf die letzte Zahl.", "Danach fand sie die richtige L\u00f6sung und zeigte auf die letzte Zahl."],
      ["Tom nickt, nennt seine Antwort und erkl\u00e4rt einen anderen Weg.", "Tom nickte, nannte seine Antwort und erkl\u00e4rte einen anderen Weg."],
      ["Am Ende legen beide die Hefte aufeinander und freuen sich \u00fcber das Ergebnis.", "Am Ende legten beide die Hefte aufeinander und freuten sich \u00fcber das Ergebnis."]
    ];
  } else if (title === "Referat \u00fcber Sterne") {
    pairs = [
      ["Noah steht vor dem Plakat mit dem Mond und atmet tief ein.", "Noah stand vor dem Plakat mit dem Mond und atmete tief ein."],
      ["Er zeigt auf den Gro\u00dfen Wagen und nennt seinen Namen deutlich.", "Er zeigte auf den Gro\u00dfen Wagen und nannte seinen Namen deutlich."],
      ["Dann erkl\u00e4rt er, warum der Mond manchmal schmal und manchmal rund aussieht.", "Dann erkl\u00e4rte er, warum der Mond manchmal schmal und manchmal rund aussah."],
      ["Kira h\u00e4lt die Planetenkarte fest und passt gut auf.", "Kira hielt die Planetenkarte fest und passte gut auf."],
      ["Noah liest einen kurzen Satz von seinem Heft ab und spricht ruhig weiter.", "Noah las einen kurzen Satz von seinem Heft ab und sprach ruhig weiter."],
      ["An einer Stelle vergisst er ein Wort, findet es aber schnell wieder.", "An einer Stelle verga\u00df er ein Wort, fand es aber schnell wieder."],
      ["Zum Schluss zeigt er noch die Rakete auf dem Bild und beantwortet eine Frage.", "Zum Schluss zeigte er noch die Rakete auf dem Bild und beantwortete eine Frage."],
      ["Danach setzt er sich hin und h\u00f6rt erleichtert den Applaus der Klasse.", "Danach setzte er sich hin und h\u00f6rte erleichtert den Applaus der Klasse."]
    ];
  } else if (title === "Regenpause im Flur") {
    pairs = [
      ["W\u00e4hrend der Regenpause bleibt Leni mit Yusuf im langen Flur.", "W\u00e4hrend der Regenpause blieb Leni mit Yusuf im langen Flur."],
      ["Die beiden holen ein Kartenspiel aus der Tasche und setzen sich auf die Bank.", "Die beiden holten ein Kartenspiel aus der Tasche und setzten sich auf die Bank."],
      ["Leni mischt die Karten gr\u00fcndlich und teilt langsam aus.", "Leni mischte die Karten gr\u00fcndlich und teilte langsam aus."],
      ["Yusuf baut daneben einen kleinen Turm aus leeren Bechern.", "Yusuf baute daneben einen kleinen Turm aus leeren Bechern."],
      ["Pl\u00f6tzlich rutscht ein Stapel weg und kippt quer \u00fcber den Boden.", "Pl\u00f6tzlich rutschte ein Stapel weg und kippte quer \u00fcber den Boden."],
      ["Beide lachen kurz, sammeln alles wieder ein und sortieren neu.", "Beide lachten kurz, sammelten alles wieder ein und sortierten neu."],
      ["Danach gewinnt Yusuf eine Runde und zeigt stolz seine letzte Karte.", "Danach gewann Yusuf eine Runde und zeigte stolz seine letzte Karte."],
      ["Als es klingelt, r\u00e4umen die beiden alles auf und laufen zur Klasse zur\u00fcck.", "Als es klingelte, r\u00e4umten die beiden alles auf und liefen zur Klasse zur\u00fcck."]
    ];
  } else if (title === "Kunst mit Wasserfarben") {
    pairs = [
      ["Sara sitzt im Kunstraum vor einem Blatt mit einem gro\u00dfen Himmel.", "Sara sa\u00df im Kunstraum vor einem Blatt mit einem gro\u00dfen Himmel."],
      ["Sie taucht den d\u00fcnnen Pinsel in Wasser und mischt zuerst ein helles Blau.", "Sie tauchte den d\u00fcnnen Pinsel in Wasser und mischte zuerst ein helles Blau."],
      ["Dann zieht sie eine breite Linie \u00fcber das obere Blatt.", "Dann zog sie eine breite Linie \u00fcber das obere Blatt."],
      ["Paul reicht ihr den Schwamm und zeigt auf eine noch freie Ecke.", "Paul reichte ihr den Schwamm und zeigte auf eine noch freie Ecke."],
      ["Sara tupft vorsichtig Wolken auf das Papier und beobachtet die verlaufenden Farben.", "Sara tupfte vorsichtig Wolken auf das Papier und beobachtete die verlaufenden Farben."],
      ["Sp\u00e4ter wagt sie einen mutigen Farbwechsel und setzt einen warmen Streifen darunter.", "Sp\u00e4ter wagte sie einen mutigen Farbwechsel und setzte einen warmen Streifen darunter."],
      ["Paul nickt, holt frisches Wasser und stellt es neben den Farbkasten.", "Paul nickte, holte frisches Wasser und stellte es neben den Farbkasten."],
      ["Am Ende h\u00e4lt Sara ihr Bild hoch und freut sich \u00fcber den leuchtenden Himmel.", "Am Ende hielt Sara ihr Bild hoch und freute sich \u00fcber den leuchtenden Himmel."]
    ];
  } else if (title === "Sporttag auf dem Hof") {
    pairs = [
      ["Beim Sporttag wartet Nils auf dem Schulhof an der Startlinie.", "Beim Sporttag wartete Nils auf dem Schulhof an der Startlinie."],
      ["Er bindet seine Sportschuhe fest und schaut zur Ziellinie.", "Er band seine Sportschuhe fest und schaute zur Ziellinie."],
      ["Lea h\u00e4lt die Startfahne hoch und z\u00e4hlt laut bis drei.", "Lea hielt die Startfahne hoch und z\u00e4hlte laut bis drei."],
      ["Dann rennt Nils los und setzt seine Arme kr\u00e4ftig ein.", "Dann rannte Nils los und setzte seine Arme kr\u00e4ftig ein."],
      ["Auf der halben Strecke stolpert er kurz, f\u00e4ngt sich aber wieder.", "Auf der halben Strecke stolperte er kurz, fing sich aber wieder."],
      ["Kurz vor dem Ziel holt er noch einen Jungen ein und sprintet vorbei.", "Kurz vor dem Ziel holte er noch einen Jungen ein und sprintete vorbei."],
      ["Danach sinkt er lachend auf die Bank und trinkt einen gro\u00dfen Schluck Wasser.", "Danach sank er lachend auf die Bank und trank einen gro\u00dfen Schluck Wasser."],
      ["Sp\u00e4ter nimmt er stolz eine Urkunde entgegen und winkt seiner Klasse zu.", "Sp\u00e4ter nahm er stolz eine Urkunde entgegen und winkte seiner Klasse zu."]
    ];
  } else if (title === "Partnerarbeit in Sachkunde") {
    pairs = [
      ["Mara arbeitet mit Jonas an einem Tisch voller Steine.", "Mara arbeitete mit Jonas an einem Tisch voller Steine."],
      ["Sie nimmt die Lupe und betrachtet zuerst einen glatten Kiesel.", "Sie nahm die Lupe und betrachtete zuerst einen glatten Kiesel."],
      ["Jonas hebt einen schweren Brocken an und legt ihn vorsichtig auf das Blatt.", "Jonas hob einen schweren Brocken an und legte ihn vorsichtig auf das Blatt."],
      ["Gemeinsam vergleichen beide Farbe, Form und Gewicht der Steine.", "Gemeinsam verglichen beide Farbe, Form und Gewicht der Steine."],
      ["Mara schreibt ihre Beobachtungen auf und unterstreicht ein wichtiges Wort.", "Mara schrieb ihre Beobachtungen auf und unterstrich ein wichtiges Wort."],
      ["Jonas entdeckt eine helle Linie im Stein und zeigt sofort darauf.", "Jonas entdeckte eine helle Linie im Stein und zeigte sofort darauf."],
      ["Dann tauschen beide ihre Fundst\u00fccke und beschreiben einen zweiten Stein.", "Dann tauschten beide ihre Fundst\u00fccke und beschrieben einen zweiten Stein."],
      ["Am Ende legen sie alles ordentlich zur\u00fcck und besprechen ihr Ergebnis.", "Am Ende legten sie alles ordentlich zur\u00fcck und besprachen ihr Ergebnis."]
    ];
  } else if (title === "Ausflug zur B\u00e4ckerei") {
    pairs = [
      ["Fina geht mit Theo in die B\u00e4ckerei an der Ecke.", "Fina ging mit Theo in die B\u00e4ckerei an der Ecke."],
      ["Gleich am Eingang riecht sie die warmen Brezeln und l\u00e4chelt.", "Gleich am Eingang roch sie die warmen Brezeln und l\u00e4chelte."],
      ["Der B\u00e4cker zeigt ein frisches Blech und erkl\u00e4rt die Arbeit mit dem Teig.", "Der B\u00e4cker zeigte ein frisches Blech und erkl\u00e4rte die Arbeit mit dem Teig."],
      ["Theo h\u00e4lt die Probiert\u00fcte fest und h\u00f6rt genau zu.", "Theo hielt die Probiert\u00fcte fest und h\u00f6rte genau zu."],
      ["Fina fragt nach dem Sesambrot und bekommt eine freundliche Antwort.", "Fina fragte nach dem Sesambrot und bekam eine freundliche Antwort."],
      ["Dann hebt der B\u00e4cker den Teigschieber hoch und zieht einen Laib aus dem Ofen.", "Dann hob der B\u00e4cker den Teigschieber hoch und zog einen Laib aus dem Ofen."],
      ["Die Kinder staunen \u00fcber den Duft und schauen noch einmal auf das Blech.", "Die Kinder staunten \u00fcber den Duft und schauten noch einmal auf das Blech."],
      ["Zum Schluss bedanken sich beide und tragen ihre T\u00fcte vorsichtig zur Schule zur\u00fcck.", "Zum Schluss bedankten sich beide und trugen ihre T\u00fcte vorsichtig zur Schule zur\u00fcck."]
    ];
  } else if (title === "Der Klassenrat am Freitag") {
    pairs = [
      ["Am Freitag sitzt die Klasse im Kreis auf ihren St\u00fchlen.", "Am Freitag sa\u00df die Klasse im Kreis auf ihren St\u00fchlen."],
      ["Ava nimmt den Rede-Stein in die Hand und beginnt ruhig zu sprechen.", "Ava nahm den Rede-Stein in die Hand und begann ruhig zu sprechen."],
      ["Sie nennt einen neuen Vorschlag f\u00fcr die Pause und schaut in die Runde.", "Sie nannte einen neuen Vorschlag f\u00fcr die Pause und schaute in die Runde."],
      ["Ben schreibt die wichtigsten Punkte auf das Protokollblatt.", "Ben schrieb die wichtigsten Punkte auf das Protokollblatt."],
      ["Einige Kinder melden sich sofort, andere denken erst noch nach.", "Einige Kinder meldeten sich sofort, andere dachten erst noch nach."],
      ["Ava h\u00f6rt gut zu, gibt den Stein weiter und wartet auf die n\u00e4chste Meinung.", "Ava h\u00f6rte gut zu, gab den Stein weiter und wartete auf die n\u00e4chste Meinung."],
      ["Am Ende stimmt die Klasse ab und entscheidet sich f\u00fcr eine gemeinsame Regel.", "Am Ende stimmte die Klasse ab und entschied sich f\u00fcr eine gemeinsame Regel."],
      ["Danach legt Ben den Bleistift weg und liest das Ergebnis noch einmal vor.", "Danach legte Ben den Bleistift weg und las das Ergebnis noch einmal vor."]
    ];
  } else if (title === "Ein Brief an die Parallelklasse") {
    pairs = [
      ["Leonie sitzt im Deutschraum vor einem leeren Blatt.", "Leonie sa\u00df im Deutschraum vor einem leeren Blatt."],
      ["Sie \u00f6ffnet das W\u00f6rterbuch und sucht nach einer freundlichen Anrede.", "Sie \u00f6ffnete das W\u00f6rterbuch und suchte nach einer freundlichen Anrede."],
      ["Dann schreibt sie den ersten Satz und achtet auf eine saubere Schrift.", "Dann schrieb sie den ersten Satz und achtete auf eine saubere Schrift."],
      ["Oskar liest leise mit und zeigt auf ein fehlendes Komma.", "Oskar las leise mit und zeigte auf ein fehlendes Komma."],
      ["Leonie verbessert die Stelle sofort und schreibt den Satz zu Ende.", "Leonie verbesserte die Stelle sofort und schrieb den Satz zu Ende."],
      ["Danach denken beide \u00fcber eine passende Frage f\u00fcr die Antwort nach.", "Danach dachten beide \u00fcber eine passende Frage f\u00fcr die Antwort nach."],
      ["Zum Schluss steckt Leonie den Brief vorsichtig in den Umschlag.", "Zum Schluss steckte Leonie den Brief vorsichtig in den Umschlag."],
      ["Oskar nickt zufrieden und legt den fertigen Brief vorne auf den Tisch.", "Oskar nickte zufrieden und legte den fertigen Brief vorne auf den Tisch."]
    ];
  } else if (title === "Das Beet hinter der Turnhalle") {
    pairs = [
      ["Jule kniet hinter der Turnhalle am Beet mit den jungen Blumen.", "Jule kniete hinter der Turnhalle am Beet mit den jungen Blumen."],
      ["Sie legt kleine Steine an den Rand und r\u00fcckt die Erde gerade.", "Sie legte kleine Steine an den Rand und r\u00fcckte die Erde gerade."],
      ["Finn h\u00e4lt die gr\u00fcne Gie\u00dfkanne fest und gie\u00dft die Pflanzen langsam.", "Finn hielt die gr\u00fcne Gie\u00dfkanne fest und goss die Pflanzen langsam."],
      ["Jule entdeckt einen Marienk\u00e4fer auf einem Blatt und beugt sich n\u00e4her heran.", "Jule entdeckte einen Marienk\u00e4fer auf einem Blatt und beugte sich n\u00e4her heran."],
      ["Dann zieht sie vorsichtig etwas Unkraut heraus und lockert die Erde.", "Dann zog sie vorsichtig etwas Unkraut heraus und lockerte die Erde."],
      ["Finn findet einen Regenwurm, hebt ihn behutsam an und setzt ihn an eine sichere Stelle.", "Finn fand einen Regenwurm, hob ihn behutsam an und setzte ihn an eine sichere Stelle."],
      ["Gemeinsam schauen beide auf die neuen Pflanzen und vergleichen ihre H\u00f6he.", "Gemeinsam schauten beide auf die neuen Pflanzen und verglichen ihre H\u00f6he."],
      ["Am Ende gehen sie zufrieden zur\u00fcck und berichten der Klasse vom Beet.", "Am Ende gingen sie zufrieden zur\u00fcck und berichteten der Klasse vom Beet."]
    ];
  } else if (title === "Tag auf dem Abenteuerspielplatz") {
    pairs = [
      ["Sami l\u00e4uft mit Pia \u00fcber den Abenteuerspielplatz zum Holzschiff.", "Sami lief mit Pia \u00fcber den Abenteuerspielplatz zum Holzschiff."],
      ["Er h\u00e4lt den Schatzplan fest und zeigt auf ein gro\u00dfes Kreuz.", "Er hielt den Schatzplan fest und zeigte auf ein gro\u00dfes Kreuz."],
      ["Pia zieht das starke Tau \u00fcber die Planke und ruft einen Piratennamen.", "Pia zog das starke Tau \u00fcber die Planke und rief einen Piratennamen."],
      ["Dann klettert Sami auf das Schiff und schaut \u00fcber die Reling.", "Dann kletterte Sami auf das Schiff und schaute \u00fcber die Reling."],
      ["Unter einer Bank entdeckt er eine alte Dose und klopft neugierig dagegen.", "Unter einer Bank entdeckte er eine alte Dose und klopfte neugierig dagegen."],
      ["Pia \u00f6ffnet den Deckel und findet einen kleinen Murmelbeutel darin.", "Pia \u00f6ffnete den Deckel und fand einen kleinen Murmelbeutel darin."],
      ["Beide jubeln laut und erfinden sofort eine neue Schatzgeschichte.", "Beide jubelten laut und erfanden sofort eine neue Schatzgeschichte."],
      ["Sp\u00e4ter setzen sie sich auf die Kante des Schiffs und teilen ihre Beute.", "Sp\u00e4ter setzten sie sich auf die Kante des Schiffs und teilten ihre Beute."]
    ];
  } else if (title === "Die Erbsen im Hochbeet") {
    pairs = [
      ["Tara steht vor dem Hochbeet und betrachtet die dicken Erbsenschoten.", "Tara stand vor dem Hochbeet und betrachtete die dicken Erbsenschoten."],
      ["Sie \u00f6ffnet das Gartenheft und notiert das heutige Datum.", "Sie \u00f6ffnete das Gartenheft und notierte das heutige Datum."],
      ["Mats nimmt die Lupe und schaut auf die feinen Blattadern.", "Mats nahm die Lupe und schaute auf die feinen Blattadern."],
      ["Dann pfl\u00fcckt Tara eine ge\u00f6ffnete Schote und legt sie auf ihre Hand.", "Dann pfl\u00fcckte Tara eine ge\u00f6ffnete Schote und legte sie auf ihre Hand."],
      ["Gemeinsam z\u00e4hlen beide die runden Erbsen und vergleichen ihre Gr\u00f6\u00dfe.", "Gemeinsam z\u00e4hlten beide die runden Erbsen und verglichen ihre Gr\u00f6\u00dfe."],
      ["Mats schreibt das Ergebnis auf und malt einen kleinen Kreis daneben.", "Mats schrieb das Ergebnis auf und malte einen kleinen Kreis daneben."],
      ["Tara steckt die restlichen Schoten in einen Korb und l\u00e4chelt \u00fcber die Ernte.", "Tara steckte die restlichen Schoten in einen Korb und l\u00e4chelte \u00fcber die Ernte."],
      ["Am Ende tragen beide den Korb vorsichtig zur\u00fcck in den Klassenraum.", "Am Ende trugen beide den Korb vorsichtig zur\u00fcck in den Klassenraum."]
    ];
  } else if (title === "Seilspringen auf dem Hof") {
    pairs = [
      ["Lias steht mit Mina auf dem Hof und h\u00e4lt ein langes Seil fest.", "Lias stand mit Mina auf dem Hof und hielt ein langes Seil fest."],
      ["Mina nennt die erste Zahl und beginnt langsam zu drehen.", "Mina nannte die erste Zahl und begann langsam zu drehen."],
      ["Lias springt im ruhigen Rhythmus \u00fcber das Seil und z\u00e4hlt leise mit.", "Lias sprang im ruhigen Rhythmus \u00fcber das Seil und z\u00e4hlte leise mit."],
      ["Nach zehn Spr\u00fcngen lacht er kurz und macht gleich weiter.", "Nach zehn Spr\u00fcngen lachte er kurz und machte gleich weiter."],
      ["Mina zeigt auf die Kreidetafel und notiert den neuen Rekord.", "Mina zeigte auf die Kreidetafel und notierte den neuen Rekord."],
      ["Dann tauschen beide die Rollen und probieren eine zweite Runde.", "Dann tauschten beide die Rollen und probierten eine zweite Runde."],
      ["Lias dreht das Seil jetzt selbst und achtet auf einen gleichm\u00e4\u00dfigen Schwung.", "Lias drehte das Seil jetzt selbst und achtete auf einen gleichm\u00e4\u00dfigen Schwung."],
      ["Am Ende klatschen beide ab und freuen sich \u00fcber den sicheren Rhythmus.", "Am Ende klatschten beide ab und freuten sich \u00fcber den sicheren Rhythmus."]
    ];
  } else if (title === "Blumen f\u00fcr den Klassenraum") {
    pairs = [
      ["Ella schneidet auf dem Hofbeet ein paar lange Stiele f\u00fcr die Vase ab.", "Ella schnitt auf dem Hofbeet ein paar lange Stiele f\u00fcr die Vase ab."],
      ["Jonte h\u00e4lt die Glasvase fest und schaut auf den bunten Strau\u00df.", "Jonte hielt die Glasvase fest und schaute auf den bunten Strau\u00df."],
      ["Pl\u00f6tzlich entdeckt Ella eine kleine Schnecke zwischen den Bl\u00fcten.", "Pl\u00f6tzlich entdeckte Ella eine kleine Schnecke zwischen den Bl\u00fcten."],
      ["Sie nimmt ein Blatt zur Hand und setzt das Tier vorsichtig an den Rand.", "Sie nahm ein Blatt zur Hand und setzte das Tier vorsichtig an den Rand."],
      ["Danach ordnen beide die Blumen neu und k\u00fcrzen noch einen Stiel.", "Danach ordneten beide die Blumen neu und k\u00fcrzten noch einen Stiel."],
      ["Jonte f\u00fcllt frisches Wasser ein und tr\u00e4gt die Vase ins Zimmer.", "Jonte f\u00fcllte frisches Wasser ein und trug die Vase ins Zimmer."],
      ["Ella stellt den Strau\u00df auf die Fensterbank und tritt einen Schritt zur\u00fcck.", "Ella stellte den Strau\u00df auf die Fensterbank und trat einen Schritt zur\u00fcck."],
      ["Gemeinsam freuen sich beide \u00fcber die Farben und den hellen Duft im Raum.", "Gemeinsam freuten sich beide \u00fcber die Farben und den hellen Duft im Raum."]
    ];
  }

  if (!pairs) {
    return null;
  }

  return {
    title: text.title,
    topic: text.topic,
    theme: text.theme,
    cliparts: text.cliparts.slice(),
    intro: text.intro,
    sentences: createSentenceObjects(pairs)
  };
}

function createSentenceObjects(pairs) {
  var sentences = [];
  var i;
  for (i = 0; i < pairs.length; i += 1) {
    sentences.push({
      present: tokenizeSentence(pairs[i][0]),
      past: tokenizeSentence(pairs[i][1])
    });
  }
  return sentences;
}

function renderThemeStage(text) {
  var cliparts = getThemeClipartsForText(text);
  var i;
  clipartList.innerHTML = "";
  for (i = 0; i < cliparts.length; i += 1) {
    var item = document.createElement("div");
    var emoji = document.createElement("span");
    item.className = "clipart-chip";
    item.style.setProperty("--twist", i % 2 === 0 ? "-4" : "4");
    emoji.className = "clipart-chip__emoji";
    emoji.textContent = cliparts[i];
    item.appendChild(emoji);
    clipartList.appendChild(item);
  }
}

function renderSentenceCard(text, sentenceIndex) {
  var sentence = text.sentences[sentenceIndex];
  var sentenceCard = document.createElement("article");
  var sentenceHead = document.createElement("div");
  var sentenceLabel = document.createElement("p");
  var sentenceHeadRight = document.createElement("div");
  var sentenceState = document.createElement("button");
  var sentenceClipartChip = document.createElement("div");
  var sentenceClipartEmoji = document.createElement("span");
  var wordsRow = document.createElement("div");
  var i;

  sentenceCard.className = "sentence-card";
  sentenceCard.setAttribute("data-theme", text.theme);
  if (state.checkedSentences[sentenceIndex]) {
    sentenceCard.className += sentenceIsCorrect(sentenceIndex) ? " is-correct" : " has-errors";
  }

  sentenceHead.className = "sentence-card__head";
  sentenceLabel.className = "sentence-label";
  sentenceLabel.textContent = "Satz " + String(sentenceIndex + 1);

  sentenceState.className = "sentence-state " + getSentenceStatusClass(sentenceIndex);
  sentenceState.type = "button";
  sentenceState.textContent = getSentenceStatusText(sentenceIndex);
  sentenceState.onclick = createCheckHandler(sentenceIndex);

  sentenceClipartChip.className = "sentence-clipart";
  sentenceClipartEmoji.className = "sentence-clipart__emoji";
  sentenceClipartEmoji.textContent = getSentenceClipart(text, sentenceIndex);
  sentenceClipartChip.appendChild(sentenceClipartEmoji);

  sentenceHeadRight.className = "sentence-head-right";
  sentenceHeadRight.appendChild(sentenceState);
  sentenceHeadRight.appendChild(sentenceClipartChip);

  sentenceHead.appendChild(sentenceLabel);
  sentenceHead.appendChild(sentenceHeadRight);

  wordsRow.className = "sentence-card__words";
  for (i = 0; i < sentence.present.length; i += 1) {
    wordsRow.appendChild(createTokenElement(sentenceIndex, i));
  }

  sentenceCard.appendChild(sentenceHead);
  sentenceCard.appendChild(wordsRow);
  if (state.revealedSolutions[sentenceIndex]) {
    sentenceCard.appendChild(createSolutionBox(sentenceIndex));
  }
  sentenceList.appendChild(sentenceCard);
}

function createTokenElement(sentenceIndex, tokenIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var tokenState = state.currentTokens[sentenceIndex][tokenIndex];
  var expected = sentence.past[tokenIndex];
  var wasEdited = tokenState.value !== tokenState.original;
  var isVerbTarget = isVerbTargetPosition(sentenceIndex, tokenIndex);
  var element;
  if (PUNCTUATION[tokenState.original]) {
    element = document.createElement("span");
    element.className = "word-punctuation";
    element.textContent = tokenState.value;
    return element;
  }
  element = document.createElement("button");
  element.type = "button";
  element.className = "word-chip";
  element.textContent = tokenState.value;
  element.onclick = createEditHandler(sentenceIndex, tokenIndex);
  if (wasEdited) {
    element.className += " is-edited";
  }
  if (isVerbTarget) {
    element.className += " is-target-verb";
  }
  if (state.checkedSentences[sentenceIndex]) {
    if (isVerbTarget) {
      element.className += tokenState.value === expected ? " is-correct" : " is-wrong";
    } else if (wasEdited && tokenState.value === expected) {
      element.className += " is-correct";
    } else if (wasEdited && tokenState.value !== expected) {
      element.className += " is-wrong";
    } else if (state.revealedSolutions[sentenceIndex] && tokenState.value !== expected) {
      element.className += " is-wrong";
    }
  }
  return element;
}

function getSentenceDifferenceInfo(sentenceIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var presentTokens = sentence.present;
  var pastTokens = sentence.past;
  var rows = [];
  var presentMatched = [];
  var pastMatched = [];
  var rowIndex;
  var columnIndex;
  var info = {
    presentChanged: {},
    pastChanged: {},
    pastChangedList: []
  };

  for (rowIndex = 0; rowIndex <= presentTokens.length; rowIndex += 1) {
    rows[rowIndex] = [];
    for (columnIndex = 0; columnIndex <= pastTokens.length; columnIndex += 1) {
      rows[rowIndex][columnIndex] = 0;
    }
  }

  for (rowIndex = presentTokens.length - 1; rowIndex >= 0; rowIndex -= 1) {
    for (columnIndex = pastTokens.length - 1; columnIndex >= 0; columnIndex -= 1) {
      if (presentTokens[rowIndex] === pastTokens[columnIndex]) {
        rows[rowIndex][columnIndex] = rows[rowIndex + 1][columnIndex + 1] + 1;
      } else if (rows[rowIndex + 1][columnIndex] >= rows[rowIndex][columnIndex + 1]) {
        rows[rowIndex][columnIndex] = rows[rowIndex + 1][columnIndex];
      } else {
        rows[rowIndex][columnIndex] = rows[rowIndex][columnIndex + 1];
      }
    }
  }

  rowIndex = 0;
  columnIndex = 0;
  while (rowIndex < presentTokens.length && columnIndex < pastTokens.length) {
    if (presentTokens[rowIndex] === pastTokens[columnIndex]) {
      presentMatched[rowIndex] = true;
      pastMatched[columnIndex] = true;
      rowIndex += 1;
      columnIndex += 1;
    } else if (rows[rowIndex + 1][columnIndex] >= rows[rowIndex][columnIndex + 1]) {
      rowIndex += 1;
    } else {
      columnIndex += 1;
    }
  }

  for (rowIndex = 0; rowIndex < presentTokens.length; rowIndex += 1) {
    if (!presentMatched[rowIndex] && !PUNCTUATION[presentTokens[rowIndex]]) {
      info.presentChanged[rowIndex] = true;
    }
  }

  for (columnIndex = 0; columnIndex < pastTokens.length; columnIndex += 1) {
    if (!pastMatched[columnIndex] && !PUNCTUATION[pastTokens[columnIndex]]) {
      info.pastChanged[columnIndex] = true;
      info.pastChangedList.push(pastTokens[columnIndex]);
    }
  }

  return info;
}

function isVerbTargetPosition(sentenceIndex, tokenIndex) {
  var sentence = getCurrentText().sentences[sentenceIndex];
  var present = sentence.present[tokenIndex];
  var differenceInfo;
  if (!present || PUNCTUATION[present]) {
    return false;
  }
  differenceInfo = getSentenceDifferenceInfo(sentenceIndex);
  return !!differenceInfo.presentChanged[tokenIndex];
}

function getThemeClipartsForText(text) {
  var defaults = {
    school: ["\ud83c\udfeb", "\ud83d\udcda", "\u270f\ufe0f", "\ud83d\udc68\u200d\ud83c\udfeb"],
    garden: ["\ud83c\udf3b", "\ud83e\udeb4", "\ud83e\udd55", "\ud83d\udca7"],
    playground: ["\ud83e\ude81", "\ud83c\udfc3", "\ud83c\udfaf", "\ud83e\uddf8"],
    family: ["\ud83c\udfe1", "\ud83c\udf72", "\ud83e\uddc1", "\ud83d\udc6a"],
    reading: ["\ud83d\udcd6", "\ud83d\udcda", "\ud83d\udd0d", "\ud83d\udcdd"],
    swim: ["\ud83c\udfca", "\ud83e\udd3f", "\u23f1\ufe0f", "\ud83d\udca6"],
    zoo: ["\ud83d\udc18", "\ud83d\udc27", "\ud83e\uddad", "\ud83d\udc3c"],
    birthday: ["\ud83c\udf82", "\ud83c\udf81", "\ud83c\udf89", "\ud83d\udd26"],
    music: ["\ud83c\udfb5", "\ud83e\udd41", "\ud83e\udd41", "\ud83c\udfa4"],
    camp: ["\u26fa", "\ud83d\udd25", "\ud83c\udf05", "\ud83e\udd7e"]
  };
  if (text && text.cliparts && text.cliparts.length) {
    return text.cliparts.slice(0, 4);
  }
  return defaults[text.theme] ? defaults[text.theme].slice() : ["\ud83d\udccc", "\ud83d\udca1", "\ud83d\udcd8", "\u2728"];
}

function getSentenceClipart(text, sentenceIndex) {
  var sentence = (text.title + " " + joinTokens(text.sentences[sentenceIndex].present)).toLowerCase();
  var keywordCliparts = [
    { words: ["schule", "klassenraum", "tafel", "heft", "lehrerin"], icon: "\ud83c\udfeb" },
    { words: ["bäckerei", "brezel", "brot", "teig", "ofen"], icon: "\ud83e\udd68" },
    { words: ["buch", "brief", "wörterbuch", "gedicht", "plakat"], icon: "\ud83d\udcd6" },
    { words: ["garten", "beet", "blumen", "gießkanne", "schote"], icon: "\ud83c\udf3f" },
    { words: ["marienkäfer", "schnecke", "regenwurm", "biene", "eichhörnchen"], icon: "\ud83d\udc1e" },
    { words: ["zoo", "robbe", "pinguin", "elefant", "löwe", "panda", "vogel"], icon: "\ud83e\uddad" },
    { words: ["ball", "tor", "seil", "springen", "sport", "lauf", "schwimmbad"], icon: "\ud83c\udfc5" },
    { words: ["kakao", "waffeln", "pancake", "muffin", "kuchen", "torte"], icon: "\ud83e\uddc7" },
    { words: ["musik", "lied", "trompete", "flöte", "trommel", "rap"], icon: "\ud83c\udfb6" },
    { words: ["see", "zelt", "lagerfeuer", "fluss", "tour", "wandern", "wald", "steg"], icon: "\u26fa" },
    { words: ["karte", "schatz", "pirat", "insel", "spielplatz", "flohmarkt"], icon: "\ud83d\uddfa\ufe0f" },
    { words: ["stern", "planet", "mond", "rakete", "planetarium", "sonnensystem"], icon: "\ud83c\udf20" },
    { words: ["roller", "fahrrad", "drachen", "handschuh", "werkstatt"], icon: "\ud83d\udef4" },
    { words: ["oma", "hund", "kaninchen", "socke", "familie"], icon: "\ud83c\udfe1" },
    { words: ["geburtstag", "luftballons", "paket", "picknick", "krone"], icon: "\ud83c\udf88" }
  ];
  var i;
  var j;
  for (i = 0; i < keywordCliparts.length; i += 1) {
    for (j = 0; j < keywordCliparts[i].words.length; j += 1) {
      if (sentence.indexOf(keywordCliparts[i].words[j]) !== -1) {
        return keywordCliparts[i].icon;
      }
    }
  }
  return getThemeClipartsForText(text)[sentenceIndex % 4];
}

function getSentenceVerbSolutions(sentenceIndex) {
  var differenceInfo = getSentenceDifferenceInfo(sentenceIndex);
  if (differenceInfo.pastChangedList.length) {
    return differenceInfo.pastChangedList.slice();
  }
  return [];
}

function saveSentenceHighscore(sentenceIndex) {
  var text = getCurrentText();
  var sentenceStore;
  if (!state.savedSentenceEntries[state.sessionPointer]) {
    state.savedSentenceEntries[state.sessionPointer] = [];
  }
  sentenceStore = state.savedSentenceEntries[state.sessionPointer];
  if (sentenceStore[sentenceIndex]) {
    return;
  }
  saveHighscoreEntry({
    entryId: createEntryId(),
    sessionId: state.sessionId,
    name: state.playerName,
    textTitle: text.title,
    sentenceLabel: "Satz " + String(sentenceIndex + 1),
    score: state.sentenceScores[sentenceIndex] || 0,
    checks: state.sentenceAttempts[sentenceIndex] + 1,
    editedCorrectInputs: state.currentEditedCorrectInputs,
    editedWrongInputs: state.currentEditedWrongInputs,
    wrongEditedWords: copyWordStats(state.currentWrongEditedWords),
    untouchedWrongWords: copyWordStats(state.currentUneditedWrongWords),
    playedAt: new Date().toISOString()
  });
  sentenceStore[sentenceIndex] = true;
}
