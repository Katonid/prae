window.PRAETERITUM_TEXT_LIBRARY = (function () {
  function tokens(sentence) {
    return sentence.match(/[A-Za-zÄÖÜäöüß]+(?:-[A-Za-zÄÖÜäöüß]+)*|[0-9]+|[,.;:!?]/g) || [];
  }

  function makeText(title, topic, theme, pairs) {
    var sentences = [];
    var i;
    for (i = 0; i < pairs.length; i += 1) {
      sentences.push({
        present: tokens(pairs[i][0]),
        past: tokens(pairs[i][1])
      });
    }
    return {
      title: title,
      topic: topic,
      theme: theme,
      cliparts: [],
      intro: "Verwandle alle Sätze in das Präteritum und achte auf die passenden Verbformen.",
      sentences: sentences
    };
  }

  function schoolText(s) {
    return makeText(s.title, "Schule", "school", [
      [s.name + " betritt am Morgen " + s.place + ".", s.name + " betrat am Morgen " + s.place + "."],
      [s.name + " legt " + s.item + " auf den Tisch und schaut zu " + s.focus + ".", s.name + " legte " + s.item + " auf den Tisch und schaute zu " + s.focus + "."],
      [s.friend + " kommt dazu, stellt " + s.tool + " bereit und hilft sofort.", s.friend + " kam dazu, stellte " + s.tool + " bereit und half sofort."],
      [s.name + " liest die Aufgabe, denkt kurz nach und beginnt konzentriert.", s.name + " las die Aufgabe, dachte kurz nach und begann konzentriert."],
      ["Gemeinsam vergleichen beide ihre Ideen und ordnen alles sorgfältig.", "Gemeinsam verglichen beide ihre Ideen und ordneten alles sorgfältig."],
      [s.name + " findet " + s.extra + " und zeigt gleich darauf.", s.name + " fand " + s.extra + " und zeigte gleich darauf."],
      [s.friend + " schreibt das Ergebnis auf und nickt zufrieden.", s.friend + " schrieb das Ergebnis auf und nickte zufrieden."],
      ["Am Ende räumen beide alles weg und sprechen über " + s.topicWord + ".", "Am Ende räumten beide alles weg und sprachen über " + s.topicWord + "."]
    ]);
  }

  function gardenText(s) {
    return makeText(s.title, "Natur", "garden", [
      [s.name + " kniet vor " + s.place + " und betrachtet " + s.focus + ".", s.name + " kniete vor " + s.place + " und betrachtete " + s.focus + "."],
      [s.name + " nimmt " + s.item + " zur Hand und lockert die Erde vorsichtig.", s.name + " nahm " + s.item + " zur Hand und lockerte die Erde vorsichtig."],
      [s.friend + " trägt " + s.tool + " heran und gießt langsam nach.", s.friend + " trug " + s.tool + " heran und goss langsam nach."],
      [s.name + " entdeckt " + s.extra + " zwischen den Blättern und beugt sich näher heran.", s.name + " entdeckte " + s.extra + " zwischen den Blättern und beugte sich näher heran."],
      ["Gemeinsam ziehen beide etwas Unkraut heraus und ordnen die Reihen neu.", "Gemeinsam zogen beide etwas Unkraut heraus und ordneten die Reihen neu."],
      [s.friend + " hebt einen kleinen Fund auf und setzt ihn an eine sichere Stelle.", s.friend + " hob einen kleinen Fund auf und setzte ihn an eine sichere Stelle."],
      [s.name + " zählt die Pflanzen noch einmal und lächelt über die Arbeit.", s.name + " zählte die Pflanzen noch einmal und lächelte über die Arbeit."],
      ["Zum Schluss tragen beide " + s.finish + " zurück und berichten von " + s.topicWord + ".", "Zum Schluss trugen beide " + s.finish + " zurück und berichteten von " + s.topicWord + "."]
    ]);
  }

  function familyText(s) {
    return makeText(s.title, "Familie", "family", [
      [s.name + " sitzt mit " + s.friend + " in " + s.place + ".", s.name + " saß mit " + s.friend + " in " + s.place + "."],
      [s.name + " holt " + s.item + " und schaut neugierig zu " + s.focus + ".", s.name + " holte " + s.item + " und schaute neugierig zu " + s.focus + "."],
      [s.friend + " erklärt den nächsten Schritt und reicht " + s.tool + ".", s.friend + " erklärte den nächsten Schritt und reichte " + s.tool + "."],
      [s.name + " probiert etwas aus, stolpert kurz und findet dann eine gute Lösung.", s.name + " probierte etwas aus, stolperte kurz und fand dann eine gute Lösung."],
      ["Danach lachen beide, ordnen alles neu und machen weiter.", "Danach lachten beide, ordneten alles neu und machten weiter."],
      [s.name + " entdeckt " + s.extra + " und zeigt es sofort.", s.name + " entdeckte " + s.extra + " und zeigte es sofort."],
      [s.friend + " nickt, nennt einen Tipp und hilft noch einmal mit.", s.friend + " nickte, nannte einen Tipp und half noch einmal mit."],
      ["Am Ende freuen sich beide über " + s.topicWord + " und räumen ruhig auf.", "Am Ende freuten sich beide über " + s.topicWord + " und räumten ruhig auf."]
    ]);
  }

  function readingText(s) {
    return makeText(s.title, "Lesen", "reading", [
      [s.name + " setzt sich in " + s.place + " und schlägt " + s.item + " auf.", s.name + " setzte sich in " + s.place + " und schlug " + s.item + " auf."],
      [s.name + " liest zuerst " + s.focus + " und hält kurz inne.", s.name + " las zuerst " + s.focus + " und hielt kurz inne."],
      [s.friend + " hört leise zu und zeigt auf " + s.tool + ".", s.friend + " hörte leise zu und zeigte auf " + s.tool + "."],
      [s.name + " sucht ein schwieriges Wort, findet es aber im Wörterbuch.", s.name + " suchte ein schwieriges Wort, fand es aber im Wörterbuch."],
      ["Gemeinsam besprechen beide die Geschichte und vergleichen ihre Ideen.", "Gemeinsam besprachen beide die Geschichte und verglichen ihre Ideen."],
      [s.name + " entdeckt " + s.extra + " und liest den Satz noch einmal.", s.name + " entdeckte " + s.extra + " und las den Satz noch einmal."],
      [s.friend + " nennt seine Lieblingsstelle und lächelt.", s.friend + " nannte seine Lieblingsstelle und lächelte."],
      ["Zum Schluss sprechen beide über " + s.topicWord + " und legen das Buch zurück.", "Zum Schluss sprachen beide über " + s.topicWord + " und legten das Buch zurück."]
    ]);
  }

  function swimText(s) {
    return makeText(s.title, "Sport", "swim", [
      [s.name + " steht am Beckenrand und schaut auf " + s.focus + ".", s.name + " stand am Beckenrand und schaute auf " + s.focus + "."],
      [s.name + " nimmt " + s.item + " und atmet tief ein.", s.name + " nahm " + s.item + " und atmete tief ein."],
      [s.friend + " hält " + s.tool + " fest und zählt laut bis drei.", s.friend + " hielt " + s.tool + " fest und zählte laut bis drei."],
      [s.name + " springt ins Wasser und zieht kräftig durch.", s.name + " sprang ins Wasser und zog kräftig durch."],
      ["Nach der Wende schwimmt " + s.name + " ruhiger und achtet auf den Armzug.", "Nach der Wende schwamm " + s.name + " ruhiger und achtete auf den Armzug."],
      [s.friend + " ruft einen kurzen Tipp und zeigt auf " + s.extra + ".", s.friend + " rief einen kurzen Tipp und zeigte auf " + s.extra + "."],
      [s.name + " erreicht das Ziel, taucht auf und lächelt erleichtert.", s.name + " erreichte das Ziel, tauchte auf und lächelte erleichtert."],
      ["Am Ende sprechen beide über " + s.topicWord + " und gehen zufrieden aus dem Bad.", "Am Ende sprachen beide über " + s.topicWord + " und gingen zufrieden aus dem Bad."]
    ]);
  }

  function zooText(s) {
    return makeText(s.title, "Zoo", "zoo", [
      [s.name + " steht vor " + s.place + " und betrachtet " + s.focus + ".", s.name + " stand vor " + s.place + " und betrachtete " + s.focus + "."],
      [s.name + " nimmt " + s.item + " in die Hand und liest das Schild genau.", s.name + " nahm " + s.item + " in die Hand und las das Schild genau."],
      [s.friend + " zeigt auf " + s.tool + " und staunt laut.", s.friend + " zeigte auf " + s.tool + " und staunte laut."],
      [s.name + " hört ein Geräusch, dreht sich um und entdeckt " + s.extra + ".", s.name + " hörte ein Geräusch, drehte sich um und entdeckte " + s.extra + "."],
      ["Gemeinsam beobachten beide das Tier noch eine Weile und vergleichen ihre Vermutungen.", "Gemeinsam beobachteten beide das Tier noch eine Weile und verglichen ihre Vermutungen."],
      [s.friend + " liest eine spannende Info vor und nickt dabei.", s.friend + " las eine spannende Info vor und nickte dabei."],
      [s.name + " zeigt noch einmal auf das Tier und nennt " + s.topicWord + ".", s.name + " zeigte noch einmal auf das Tier und nannte " + s.topicWord + "."],
      ["Am Ende gehen beide weiter und sprechen noch lange über den Besuch.", "Am Ende gingen beide weiter und sprachen noch lange über den Besuch."]
    ]);
  }

  function musicText(s) {
    return makeText(s.title, "Musik", "music", [
      [s.name + " sitzt in " + s.place + " und schaut auf " + s.focus + ".", s.name + " saß in " + s.place + " und schaute auf " + s.focus + "."],
      [s.name + " nimmt " + s.item + " und probiert die ersten Töne.", s.name + " nahm " + s.item + " und probierte die ersten Töne."],
      [s.friend + " hält " + s.tool + " bereit und hört aufmerksam zu.", s.friend + " hielt " + s.tool + " bereit und hörte aufmerksam zu."],
      [s.name + " beginnt sicher, verliert kurz den Takt und findet ihn wieder.", s.name + " begann sicher, verlor kurz den Takt und fand ihn wieder."],
      ["Danach spielen beide die Stelle noch einmal und achten auf den Rhythmus.", "Danach spielten beide die Stelle noch einmal und achteten auf den Rhythmus."],
      [s.friend + " nennt einen Tipp und zeigt auf " + s.extra + ".", s.friend + " nannte einen Tipp und zeigte auf " + s.extra + "."],
      [s.name + " trifft den Schluss sauber und lächelt erleichtert.", s.name + " traf den Schluss sauber und lächelte erleichtert."],
      ["Am Ende sprechen beide über " + s.topicWord + " und packen ihre Sachen ein.", "Am Ende sprachen beide über " + s.topicWord + " und packten ihre Sachen ein."]
    ]);
  }

  function birthdayText(s) {
    return makeText(s.title, "Feier", "birthday", [
      [s.name + " steht in " + s.place + " und schaut auf " + s.focus + ".", s.name + " stand in " + s.place + " und schaute auf " + s.focus + "."],
      [s.name + " nimmt " + s.item + " und trägt es vorsichtig zum Tisch.", s.name + " nahm " + s.item + " und trug es vorsichtig zum Tisch."],
      [s.friend + " bringt " + s.tool + " mit und hilft gleich beim Vorbereiten.", s.friend + " brachte " + s.tool + " mit und half gleich beim Vorbereiten."],
      [s.name + " entdeckt " + s.extra + " und ruft erfreut die anderen.", s.name + " entdeckte " + s.extra + " und rief erfreut die anderen."],
      ["Gemeinsam schmücken beide alles weiter und vergleichen ihre Ideen.", "Gemeinsam schmückten beide alles weiter und verglichen ihre Ideen."],
      [s.friend + " verteilt noch etwas und lächelt zufrieden.", s.friend + " verteilte noch etwas und lächelte zufrieden."],
      [s.name + " schaut noch einmal auf den Tisch und freut sich über " + s.topicWord + ".", s.name + " schaute noch einmal auf den Tisch und freute sich über " + s.topicWord + "."],
      ["Kurz darauf beginnt das Fest und alle klatschen fröhlich.", "Kurz darauf begann das Fest und alle klatschten fröhlich."]
    ]);
  }

  function campText(s) {
    return makeText(s.title, "Ferien", "camp", [
      [s.name + " steht vor " + s.place + " und schaut auf " + s.focus + ".", s.name + " stand vor " + s.place + " und schaute auf " + s.focus + "."],
      [s.name + " nimmt " + s.item + " und prüft alles noch einmal.", s.name + " nahm " + s.item + " und prüfte alles noch einmal."],
      [s.friend + " bringt " + s.tool + " mit und hilft beim Aufbau.", s.friend + " brachte " + s.tool + " mit und half beim Aufbau."],
      [s.name + " entdeckt " + s.extra + " und zeigt sofort darauf.", s.name + " entdeckte " + s.extra + " und zeigte sofort darauf."],
      ["Gemeinsam ziehen beide fest, ordnen alles neu und arbeiten weiter.", "Gemeinsam zogen beide fest, ordneten alles neu und arbeiteten weiter."],
      [s.friend + " gibt einen kurzen Tipp und lacht danach.", s.friend + " gab einen kurzen Tipp und lachte danach."],
      [s.name + " lehnt sich kurz zurück und hört in die Umgebung.", s.name + " lehnte sich kurz zurück und hörte in die Umgebung."],
      ["Am Ende sprechen beide über " + s.topicWord + " und setzen sich ans Feuer.", "Am Ende sprachen beide über " + s.topicWord + " und setzten sich ans Feuer."]
    ]);
  }

  function playgroundText(s) {
    return makeText(s.title, "Freizeit", "playground", [
      [s.name + " läuft zu " + s.place + " und schaut auf " + s.focus + ".", s.name + " lief zu " + s.place + " und schaute auf " + s.focus + "."],
      [s.name + " nimmt " + s.item + " und erklärt den ersten Schritt.", s.name + " nahm " + s.item + " und erklärte den ersten Schritt."],
      [s.friend + " bringt " + s.tool + " mit und hört aufmerksam zu.", s.friend + " brachte " + s.tool + " mit und hörte aufmerksam zu."],
      [s.name + " beginnt mutig, stolpert kurz und fängt sich wieder.", s.name + " begann mutig, stolperte kurz und fing sich wieder."],
      ["Danach probieren beide eine neue Idee und lachen laut.", "Danach probierten beide eine neue Idee und lachten laut."],
      [s.friend + " findet " + s.extra + " und zeigt es stolz herum.", s.friend + " fand " + s.extra + " und zeigte es stolz herum."],
      [s.name + " ruft einen Spielnamen und winkt den anderen Kindern zu.", s.name + " rief einen Spielnamen und winkte den anderen Kindern zu."],
      ["Am Ende sprechen beide über " + s.topicWord + " und gehen zufrieden nach Hause.", "Am Ende sprachen beide über " + s.topicWord + " und gingen zufrieden nach Hause."]
    ]);
  }

  var texts = [];
  var i;
  var schoolSpecs = [
    { title: "Frühdienst im Klassenraum", name: "Jana", friend: "Emil", place: "den Klassenraum", item: "ihren Ranzen", focus: "den Wochenplan", tool: "den Tafelschwamm", extra: "einen roten Stift", topicWord: "den Tafeldienst" },
    { title: "Das neue Matheheft", name: "Mila", friend: "Tom", place: "das Klassenzimmer", item: "ihr Matheheft", focus: "die erste Aufgabe", tool: "den Radiergummi", extra: "eine richtige Lösung", topicWord: "den Rechenweg" },
    { title: "Referat über Sterne", name: "Noah", friend: "Kira", place: "den Sachkunderaum", item: "sein Sternenheft", focus: "das Plakat mit dem Mond", tool: "die Planetenkarte", extra: "eine Rakete auf dem Bild", topicWord: "das Sonnensystem" },
    { title: "Regenpause im Flur", name: "Leni", friend: "Yusuf", place: "den langen Flur", item: "ein Kartenspiel", focus: "den Kartenstapel", tool: "leere Becher", extra: "eine fehlende Karte", topicWord: "die Regenpause" },
    { title: "Kunst mit Wasserfarben", name: "Sara", friend: "Paul", place: "den Kunstraum", item: "den Pinsel", focus: "den blauen Himmel", tool: "den Schwamm", extra: "einen warmen Farbton", topicWord: "das Bild" },
    { title: "Sporttag auf dem Hof", name: "Nils", friend: "Lea", place: "den Schulhof", item: "seine Sportschuhe", focus: "die Ziellinie", tool: "die Startfahne", extra: "eine freie Bahn", topicWord: "den Staffellauf" },
    { title: "Partnerarbeit in Sachkunde", name: "Mara", friend: "Jonas", place: "den Forschertisch", item: "die Lupe", focus: "die Steinekiste", tool: "das Notizblatt", extra: "eine helle Linie im Stein", topicWord: "die Gesteine" },
    { title: "Ausflug zur Bäckerei", name: "Fina", friend: "Theo", place: "die Bäckerei", item: "die Probiertüte", focus: "die warmen Brezeln", tool: "den Teigschieber", extra: "ein frisches Blech", topicWord: "das Backen" },
    { title: "Der Klassenrat am Freitag", name: "Ava", friend: "Ben", place: "den Sitzkreis", item: "den Rede-Stein", focus: "die neue Regel", tool: "das Protokollblatt", extra: "einen guten Vorschlag", topicWord: "die Klassenregeln" },
    { title: "Ein Brief an die Parallelklasse", name: "Leonie", friend: "Oskar", place: "den Deutschraum", item: "den Brief", focus: "die Anrede", tool: "den Füller", extra: "ein fehlendes Komma", topicWord: "die Antwort" }
  ];
  var gardenSpecs = [
    { title: "Das Beet hinter der Turnhalle", name: "Jule", friend: "Finn", place: "dem Beet hinter der Turnhalle", item: "die kleine Harke", focus: "die jungen Blumen", tool: "die grüne Gießkanne", extra: "einen Marienkäfer", finish: "die Gießkanne", topicWord: "den Garten" },
    { title: "Die Erbsen im Hochbeet", name: "Tara", friend: "Mats", place: "dem Hochbeet", item: "das Gartenheft", focus: "die dicken Schoten", tool: "die Lupe", extra: "eine geöffnete Schote", finish: "den Korb", topicWord: "die Ernte" },
    { title: "Blumen für den Klassenraum", name: "Ella", friend: "Jonte", place: "dem Hofbeet", item: "die Schere", focus: "den bunten Strauß", tool: "die Glasvase", extra: "eine kleine Schnecke", finish: "die Vase", topicWord: "die Blumen" },
    { title: "Der Regenmesser im Garten", name: "Yara", friend: "Leo", place: "dem Gartenweg", item: "das Lineal", focus: "den Regenmesser", tool: "das Wetterheft", extra: "schwimmende Blätter", finish: "das Wetterheft", topicWord: "den Regen" },
    { title: "Das Insektenhotel", name: "Luca", friend: "Mia", place: "dem Schulgarten", item: "Zapfen und Schilf", focus: "das Holzhaus", tool: "die Schraubenkiste", extra: "eine Biene am Zaun", finish: "die Kiste", topicWord: "die Insekten" },
    { title: "Kräuter auf der Fensterbank", name: "Nora", friend: "Sami", place: "den kleinen Töpfen", item: "die Sprühflasche", focus: "die Kräuterblätter", tool: "die Gießkanne", extra: "einen starken Duft", finish: "die Sprühflasche", topicWord: "die Kräuter" },
    { title: "Das Apfelprojekt", name: "Mina", friend: "Karl", place: "dem Schulgarten", item: "den Korb", focus: "die roten Äpfel", tool: "das Arbeitsblatt", extra: "einen Wurmgang", finish: "den Korb", topicWord: "die Apfelernte" },
    { title: "Morgens am Teich", name: "Pia", friend: "Aras", place: "dem kleinen Teich", item: "das Beobachtungsheft", focus: "das Wasser", tool: "die Lupe", extra: "eine Libelle", finish: "das Heft", topicWord: "den Teich" },
    { title: "Samen im Blumentopf", name: "Hedi", friend: "Lias", place: "dem Blumentopf", item: "die Samenkörner", focus: "die dunkle Erde", tool: "die Schaufel", extra: "einen ersten Keim", finish: "die Schaufel", topicWord: "das Pflanzen" },
    { title: "Die Bohnenstangen", name: "Kaya", friend: "Rico", place: "den langen Bohnenreihen", item: "die Schnur", focus: "die hohen Stangen", tool: "den Spaten", extra: "eine lose Schleife", finish: "die Schnur", topicWord: "die Bohnen" }
  ];
  var familySpecs = [
    { title: "Besuch bei Oma", name: "Mila", friend: "Oma", place: "der Küche", item: "die Kuchenteller", focus: "den Waffelteig", tool: "die Kanne", extra: "eine alte Spieluhr", topicWord: "den Nachmittag" },
    { title: "Der Hund auf dem Sofa", name: "Tabea", friend: "Jonas", place: "dem Wohnzimmer", item: "ein Leckerli", focus: "Bello auf dem Sofa", tool: "den Wassernapf", extra: "ein trockenes Kissen", topicWord: "den Hund" },
    { title: "Ein Streit um das Bausteinhaus", name: "Ida", friend: "Moritz", place: "dem Kinderzimmer", item: "einen Fensterstein", focus: "den umgekippten Turm", tool: "die Grundplatte", extra: "ein rotes Dachteil", topicWord: "die Versöhnung" },
    { title: "Pancakes am Sonntag", name: "Elias", friend: "Mama", place: "der Küche", item: "die Schüssel mit Teig", focus: "den ersten Pancake", tool: "den Schneebesen", extra: "eine Banane", topicWord: "das Frühstück" },
    { title: "Die verschwundene Socke", name: "Paula", friend: "Papa", place: "dem Schlafzimmer", item: "die blaue Socke", focus: "den Kleiderhaufen", tool: "die obere Schublade", extra: "eine alte Jacke", topicWord: "die Suche" },
    { title: "Das Regal für Comics", name: "Amelie", friend: "Onkel", place: "dem Wohnzimmer", item: "die Seitenwand", focus: "das neue Regal", tool: "die Schraubenkiste", extra: "eine Rückwand", topicWord: "das Regal" },
    { title: "Abendfutter für das Kaninchen", name: "Selma", friend: "Papa", place: "dem Hofstall", item: "die Möhren", focus: "das Kaninchen", tool: "die Wasserflasche", extra: "frisches Stroh", topicWord: "das Futter" },
    { title: "Der Geburtstagskalender", name: "Fine", friend: "Joris", place: "dem Flur", item: "bunte Karten", focus: "den Monatsstreifen", tool: "den Filzstift", extra: "ein Klebeband", topicWord: "den Kalender" },
    { title: "Die neue Tischdecke", name: "Lara", friend: "Mama", place: "dem Esszimmer", item: "die Tischdecke", focus: "den gedeckten Tisch", tool: "die Blumen", extra: "eine schiefe Kerze", topicWord: "das Abendessen" },
    { title: "Kekse für die Nachbarn", name: "Rina", friend: "Opa", place: "der Küche", item: "den Teig", focus: "das Backblech", tool: "die Ausstechformen", extra: "ein Sternkeks", topicWord: "die Kekse" }
  ];
  var readingSpecs = [
    { title: "Suche im Büchereikeller", name: "Arda", friend: "Mila", place: "der Stadtbücherei", item: "das Vulkanbuch", focus: "den Kistentitel", tool: "die Regalliste", extra: "einen roten Rücken", topicWord: "das Suchbuch" },
    { title: "Vorlesen in der Kuschelecke", name: "Nela", friend: "Moritz", place: "der Kuschelecke", item: "die Tiergeschichte", focus: "die Fuchs-Stimme", tool: "das Kissen", extra: "eine spannende Stelle", topicWord: "die Geschichte" },
    { title: "Der neue Bücherausweis", name: "Younes", friend: "Sara", place: "der Kinderbücherei", item: "das Dinosaurierbuch", focus: "die Fossilienseite", tool: "den Ausweis", extra: "einen Stempelzettel", topicWord: "die Ausleihe" },
    { title: "Das geheime Regal", name: "Rina", friend: "Lea", place: "dem Klassenraum", item: "das Überraschungsbuch", focus: "den Umschlag mit Nummer sieben", tool: "die Tippkiste", extra: "eine Inselkarte", topicWord: "das Geheimfach" },
    { title: "Das Buch mit der Karte", name: "Lea", friend: "Tom", place: "dem Fensterplatz", item: "das Abenteuerbuch", focus: "die Inselkarte", tool: "den grünen Stift", extra: "ein rotes Kreuz", topicWord: "die Reise" },
    { title: "Ein Gedicht für den Frühling", name: "Zoe", friend: "Erik", place: "dem Deutschraum", item: "das Gedichtblatt", focus: "die Windzeile", tool: "das Heft", extra: "eine Lieblingsstrophe", topicWord: "das Gedicht" },
    { title: "Eine Lesespur im Museum", name: "Jorin", friend: "Mia", place: "dem Museum", item: "die Lesekarte", focus: "das Schlusswort", tool: "das Museumsheft", extra: "eine goldene Uhr", topicWord: "die Spur" },
    { title: "Der Zeitungsartikel", name: "Ben", friend: "Aylin", place: "dem Lesetisch", item: "die Kinderzeitung", focus: "die Überschrift", tool: "den Markierstift", extra: "ein unbekanntes Wort", topicWord: "den Bericht" },
    { title: "Lesen unter der Decke", name: "Noe", friend: "Lina", place: "dem Sofa", item: "das Lampenbuch", focus: "das erste Kapitel", tool: "die Decke", extra: "eine mutige Figur", topicWord: "die Geschichte" },
    { title: "Das Märchenheft", name: "Hanna", friend: "Jona", place: "dem Leseraum", item: "das Märchenheft", focus: "die Schlossseite", tool: "das Wörterbuch", extra: "eine alte Krone", topicWord: "das Märchen" }
  ];
  var swimSpecs = [
    { title: "Der erste Sprung vom Startblock", name: "Erik", friend: "Sina", focus: "die Wende", item: "die Brille", tool: "die Stoppuhr", extra: "die neue Zeit", topicWord: "das Rennen" },
    { title: "Schwimmnudeln im Becken", name: "Mona", friend: "Ali", focus: "das Untertauchen", item: "die gelbe Nudel", tool: "den Beckenrand", extra: "den zweiten Versuch", topicWord: "das Becken" },
    { title: "Bahnen im Morgenkurs", name: "Luca", friend: "Mira", focus: "die blaue Leine", item: "die Schwimmbrille", tool: "die Tafel", extra: "eine ruhige Bahn", topicWord: "den Kurs" },
    { title: "Tauchen nach Ringen", name: "Emir", friend: "Paula", focus: "die bunten Ringe", item: "das Handtuch", tool: "die Kiste", extra: "den tiefsten Ring", topicWord: "das Tauchen" },
    { title: "Rückenschwimmen lernen", name: "Leni", friend: "Theo", focus: "die Decke über dem Wasser", item: "die Schwimmhilfe", tool: "die Uhr", extra: "einen geraden Armzug", topicWord: "das Rückenschwimmen" },
    { title: "Wettspiel im Nichtschwimmerbecken", name: "Pia", friend: "Nils", focus: "den Wasserball", item: "die rote Kappe", tool: "die Pfeife", extra: "einen schnellen Zug", topicWord: "das Spiel" },
    { title: "Die Seepferdchenprobe", name: "Mia", friend: "Karl", focus: "die kleine Fahne", item: "das Armband", tool: "die Liste", extra: "die Urkunde", topicWord: "die Prüfung" },
    { title: "Training mit der Trainerin", name: "Jara", friend: "Tom", focus: "den Armzug", item: "die Flossen", tool: "die Tafel", extra: "einen kurzen Hinweis", topicWord: "das Training" },
    { title: "Spritzer im Freibad", name: "Ben", friend: "Mara", focus: "die Leiter", item: "die Badetasche", tool: "den Ball", extra: "eine freie Bahn", topicWord: "den Freibadtag" },
    { title: "Die letzte Bahn", name: "Rico", friend: "Lea", focus: "das Zielbrett", item: "die Kappe", tool: "die Uhr", extra: "einen tiefen Atemzug", topicWord: "den Endspurt" }
  ];
  var zooSpecs = [
    { title: "Die Robbe im Morgenkreis", name: "Mira", friend: "Ben", place: "dem Robbenbecken", item: "das Tierheft", focus: "die silberne Flosse", tool: "den Zooplan", extra: "die springende Robbe", topicWord: "die Robbe" },
    { title: "Das große Elefantenhaus", name: "Amir", friend: "Lina", place: "dem Elefantenhaus", item: "das Notizblatt", focus: "den langen Rüssel", tool: "den Plan", extra: "eine Sandwolke", topicWord: "den Elefanten" },
    { title: "Nachts im Tropenhaus", name: "Tom", friend: "Nina", place: "dem Tropenhaus", item: "das Infoblatt", focus: "den kleinen Frosch", tool: "das Heft", extra: "eine Pflanzenwand", topicWord: "den Regenwald" },
    { title: "Der Tierpfleger im Vogelhaus", name: "Hanna", friend: "Mila", place: "dem Vogelhaus", item: "den Fruchteimer", focus: "das rote Gefieder", tool: "das Zeichenblatt", extra: "ein Nest", topicWord: "die Vögel" },
    { title: "Kurz vor der Löwenfütterung", name: "Nora", friend: "Timo", place: "dem Löwengehege", item: "die Eintrittskarte", focus: "die großen Pfoten", tool: "das Beobachtungsblatt", extra: "ein tiefes Brummen", topicWord: "den Löwen" },
    { title: "Ein Panda aus Papier", name: "Elias", friend: "Juna", place: "dem Klassenraum", item: "das Tonpapier", focus: "den Bambus", tool: "die Schere", extra: "grüne Papierstreifen", topicWord: "den Panda" },
    { title: "Abschied von den Seehunden", name: "Luca", friend: "Mama", place: "dem Seehundbecken", item: "das Ticket", focus: "die drehende Schnauze", tool: "den Zooplan", extra: "einen Wasserball", topicWord: "den Seehund" },
    { title: "Die Giraffen am Zaun", name: "Sami", friend: "Pia", place: "dem Giraffengehege", item: "das Faltblatt", focus: "den langen Hals", tool: "den Futterkorb", extra: "eine hohe Leiter", topicWord: "die Giraffe" },
    { title: "Pinguine auf dem Felsen", name: "Leo", friend: "Tara", place: "dem Pinguinbecken", item: "das Notizheft", focus: "den nassen Felsen", tool: "die Kamera", extra: "einen schnellen Sprung", topicWord: "die Pinguine" },
    { title: "Das Reptilienhaus", name: "Ava", friend: "Jonas", place: "dem Reptilienhaus", item: "das Heft", focus: "die grüne Schlange", tool: "den Lageplan", extra: "eine Häutung", topicWord: "die Reptilien" }
  ];
  var musicSpecs = [
    { title: "Die Trommelprobe", name: "Ben", friend: "Lotte", place: "dem Musikraum", item: "die Schlägel", focus: "den Takt", tool: "die Rassel", extra: "den lauten Schluss", topicWord: "den Rhythmus" },
    { title: "Die Flöte im Wohnzimmer", name: "Sina", friend: "Opa", place: "dem Wohnzimmer", item: "die Flöte", focus: "die schnelle Stelle", tool: "das Liedblatt", extra: "einen Atemtipp", topicWord: "das Üben" },
    { title: "Ein Rap für das Sommerfest", name: "Kaya", friend: "Omar", place: "dem AG-Raum", item: "das Reimblatt", focus: "den Beat", tool: "den Stift", extra: "den Refrain", topicWord: "den Rap" },
    { title: "Das Orchester aus Alltagsdingen", name: "Zoe", friend: "Jan", place: "dem Klassenraum", item: "die Holzlöffel", focus: "den neuen Klang", tool: "die Reisdose", extra: "den Schlussakkord", topicWord: "das Orchester" },
    { title: "Die Stimme fürs Theaterlied", name: "Ava", friend: "Mia", place: "dem Musikraum", item: "das Liedblatt", focus: "den hohen Ton", tool: "die Chorreihe", extra: "einen sicheren Einsatz", topicWord: "das Theaterlied" },
    { title: "Trompetenluft auf dem Schulhof", name: "Hannes", friend: "Lara", place: "dem Schulhof", item: "die Trompete", focus: "das Notenblatt", tool: "die Klammermappe", extra: "die große Melodie", topicWord: "die Probe" },
    { title: "Das Tanzzeichen", name: "Marlon", friend: "Tessa", place: "der Turnhalle", item: "die Schrittkarte", focus: "die Lehrerin", tool: "die Musikbox", extra: "den Schlusskreis", topicWord: "den Tanz" },
    { title: "Gitarrenklang im Nebenraum", name: "Yara", friend: "Noah", place: "dem Nebenraum", item: "die kleine Gitarre", focus: "die Akkorde", tool: "das Heft", extra: "einen sauberen Schluss", topicWord: "das Lied" },
    { title: "Das Klangspiel", name: "Lina", friend: "Erik", place: "dem Musikraum", item: "die Schlägel", focus: "die Metallstäbe", tool: "den Notenzettel", extra: "einen hellen Ton", topicWord: "das Klangspiel" },
    { title: "Singen vor der Klasse", name: "Mira", friend: "Frau Kern", place: "dem Klassenraum", item: "das Liedblatt", focus: "die erste Zeile", tool: "das Zeichen", extra: "einen mutigen Einsatz", topicWord: "das Singen" }
  ];
  var birthdaySpecs = [
    { title: "Topfschlagen im Flur", name: "Finn", friend: "Lina", place: "dem Flur", item: "den Kochlöffel", focus: "den Topf", tool: "die Schachtel", extra: "ein kleines Auto", topicWord: "das Spiel" },
    { title: "Die Schatzkarte für das Fest", name: "Tilda", friend: "Paul", place: "dem Garten", item: "die Schatzkarte", focus: "den roten Pfeil", tool: "die Blechdose", extra: "eine Muschel", topicWord: "die Schatzsuche" },
    { title: "Kerzen auf der Torte", name: "Lara", friend: "Oma", place: "dem Esszimmer", item: "die Kerzen", focus: "die Flammen", tool: "den Tortenheber", extra: "ein großes Stück", topicWord: "das Auspusten" },
    { title: "Das Riesenpaket", name: "Ben", friend: "Tante", place: "dem Wohnzimmer", item: "die Schleife", focus: "das große Geschenk", tool: "die Schere", extra: "eine zweite Schachtel", topicWord: "das Auspacken" },
    { title: "Muffins für die Klasse", name: "Ece", friend: "Mama", place: "der Küche", item: "die Muffinform", focus: "den Kakaoduft", tool: "die Streuselpackung", extra: "ein buntes Förmchen", topicWord: "die Muffins" },
    { title: "Schatten an der Gartenwand", name: "Hedi", friend: "Opa", place: "dem Garten", item: "die Taschenlampe", focus: "den großen Hasen", tool: "die Decke", extra: "einen Vogel aus Fingern", topicWord: "das Schattenspiel" },
    { title: "Die Feier im Vereinshaus", name: "Rico", friend: "Mila", place: "dem Vereinshaus", item: "die Girlanden", focus: "das große Paket", tool: "die Saftkaraffe", extra: "ein Namensschild", topicWord: "das Fest" },
    { title: "Luftballons am Fenster", name: "Pia", friend: "Emir", place: "dem Wohnzimmer", item: "die Luftballons", focus: "die bunte Schnur", tool: "das Klebeband", extra: "ein geplatzter Ballon", topicWord: "die Deko" },
    { title: "Das Picknick im Park", name: "Nele", friend: "Jana", place: "dem Park", item: "die Picknickdecke", focus: "den Korb", tool: "die Saftflasche", extra: "einen Pappteller", topicWord: "das Picknick" },
    { title: "Die Geburtstagskrone", name: "Rosa", friend: "Leo", place: "dem Kinderzimmer", item: "die Papierkrone", focus: "die Glitzersterne", tool: "die Schere", extra: "ein schiefes Band", topicWord: "die Krone" }
  ];
  var campSpecs = [
    { title: "Ein Zelt im Garten", name: "Jana", friend: "Timo", place: "dem Gartenzelt", item: "die Heringe", focus: "den Regenschauer", tool: "die Lampe", extra: "das dichte Dach", topicWord: "die Zeltnacht" },
    { title: "Eine Nacht am Lagerfeuer", name: "Lina", friend: "Tim", place: "dem Lagerplatz", item: "den Brotstock", focus: "die Glut", tool: "den Becher Wasser", extra: "eine Geschichte", topicWord: "das Feuer" },
    { title: "Frühstück vor der Bergtour", name: "Emil", friend: "Rike", place: "der Waldhütte", item: "den Rucksack", focus: "den Anstieg", tool: "den Becher Tee", extra: "einen festen Knoten", topicWord: "die Tour" },
    { title: "Würstchen am Feuer", name: "Noe", friend: "Hedi", place: "dem Feuerplatz", item: "den Brotstock", focus: "die Glut", tool: "den Teller", extra: "den Senf", topicWord: "das Abendessen" },
    { title: "Der Badetag am Fluss", name: "Mats", friend: "Lina", place: "dem Flussufer", item: "das Handtuch", focus: "das kalte Wasser", tool: "die Saftflasche", extra: "einen flachen Stein", topicWord: "den Fluss" },
    { title: "Regen im Ferienlager", name: "Kira", friend: "Jan", place: "dem Zeltdorf", item: "die Gummistiefel", focus: "die nasse Wiese", tool: "die Plane", extra: "eine trockene Ecke", topicWord: "den Regenschauer" },
    { title: "Der erste Morgen im Zelt", name: "Paul", friend: "Mia", place: "dem Zelt", item: "die Taschenlampe", focus: "den hellen Himmel", tool: "die Müslischüssel", extra: "einen Vogelruf", topicWord: "den Morgen" },
    { title: "Spuren im Wald", name: "Sami", friend: "Lea", place: "dem Waldweg", item: "das Fernglas", focus: "den schmalen Pfad", tool: "die Karte", extra: "einen kleinen Abdruck", topicWord: "die Wanderung" },
    { title: "Abend am Steg", name: "Alma", friend: "Joris", place: "dem Steg", item: "die Angel", focus: "das ruhige Wasser", tool: "den Eimer", extra: "einen silbernen Fisch", topicWord: "den Abend" },
    { title: "Die Hütte am See", name: "Benni", friend: "Aylin", place: "der Holzhütte", item: "den Schlüssel", focus: "die knarrende Tür", tool: "die Decke", extra: "ein altes Regal", topicWord: "die Hütte" }
  ];
  var playgroundSpecs = [
    { title: "Tag auf dem Abenteuerspielplatz", name: "Sami", friend: "Pia", place: "dem Holzschiff", item: "den Schatzplan", focus: "das große Kreuz", tool: "das Tau", extra: "eine alte Dose", topicWord: "das Piratenspiel" },
    { title: "Seilspringen auf dem Hof", name: "Lias", friend: "Mina", place: "dem Schulhof", item: "das lange Seil", focus: "die Sprungzahl", tool: "die Kreidetafel", extra: "einen neuen Rekord", topicWord: "das Seilspringen" },
    { title: "Roller auf der Schulstraße", name: "Ole", friend: "Henri", place: "dem Parcours", item: "den Roller", focus: "die scharfe Kurve", tool: "die Hütchen", extra: "eine sichere Spur", topicWord: "die Proberunde" },
    { title: "Fußball am Nachmittag", name: "Noor", friend: "Malik", place: "dem Bolzplatz", item: "den Ball", focus: "das linke Tor", tool: "die weiße Kreide", extra: "einen schnellen Pass", topicWord: "das Spiel" },
    { title: "Der Drachen im Herbstwind", name: "Benni", friend: "Romy", place: "der Wiese am Feld", item: "die Schnurrolle", focus: "den langen Schweif", tool: "den Drachenstab", extra: "einen festen Knoten", topicWord: "den Flug" },
    { title: "Der verlorene Handschuh", name: "Zina", friend: "Oskar", place: "dem Heimweg", item: "den blauen Handschuh", focus: "die Bank am Zaun", tool: "die Jackentasche", extra: "etwas Blaues im Gras", topicWord: "die Suche" },
    { title: "Das Fahrrad in der Werkstatt", name: "Sami", friend: "Onkel", place: "dem Hof", item: "das Hinterrad", focus: "die abgesprungene Kette", tool: "den Schlüssel", extra: "einen Lappen", topicWord: "die Reparatur" },
    { title: "Das Spiel im Schaufenster", name: "Jan", friend: "Kira", place: "dem Schaufenster", item: "den Wunschzettel", focus: "den Baukasten", tool: "das Preisschild", extra: "einen Spieletitel", topicWord: "das Spiel" },
    { title: "Die Schneeburg", name: "Leo", friend: "Mara", place: "dem Hofrand", item: "den Eimer Schnee", focus: "die glitzernden Türme", tool: "die Lampe", extra: "einen tiefen Eingang", topicWord: "den Schnee" },
    { title: "Der Flohmarkt im Hof", name: "Tara", friend: "Jonas", place: "dem Hofmarkt", item: "die Taschenlampe", focus: "die Murmeln auf der Decke", tool: "den Tauschzettel", extra: "eine grüne Murmel", topicWord: "den Tausch" }
  ];

  for (i = 0; i < schoolSpecs.length; i += 1) {
    texts.push(schoolText(schoolSpecs[i]));
    texts.push(gardenText(gardenSpecs[i]));
    texts.push(familyText(familySpecs[i]));
    texts.push(readingText(readingSpecs[i]));
    texts.push(swimText(swimSpecs[i]));
    texts.push(zooText(zooSpecs[i]));
    texts.push(musicText(musicSpecs[i]));
    texts.push(birthdayText(birthdaySpecs[i]));
    texts.push(campText(campSpecs[i]));
    texts.push(playgroundText(playgroundSpecs[i]));
  }

  return texts;
}());
