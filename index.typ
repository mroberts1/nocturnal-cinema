// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}


#let PrettyPDF(
  // The document title.
  title: "PrettyPDF",

  // Logo in top right corner.
  typst-logo: none,

  // The document content.
  body
) = {

  // Set document metadata.
  set document(title: title)
  
  // Configure pages.
  set page(
    margin: (left: 2cm, right: 1.5cm, top: 2cm, bottom: 2cm),
    numbering: "1",
    number-align: right,
    background: place(right + top, rect(
      fill: rgb("#E6E6FA"),
      height: 100%,
      width: 3cm,
    ))
  )
  
  // Set the body font.
  set text(10pt, font: "Ubuntu")

  // Configure headings.
  show heading.where(level: 1): set block(below: 0.8em)
  show heading.where(level: 1): underline
  show heading.where(level: 2): set block(above: 0.5cm, below: 0.5cm)

  // Links should be purple.
  show link: set text(rgb("#800080"))

  // Configure light purple border.
  show figure: it => block({
    move(dx: -3%, dy: 1.5%, rect(
      fill: rgb("FF7D79"),
      inset: 0pt,
      move(dx: 3%, dy: -1.5%, it.body)
    ))
  })

  // Purple border column
  grid(
    columns: (1fr, 0.75cm),
    column-gutter: 2.5cm,

    // Title.
    text(font: "Ubuntu", 20pt, weight: 800, upper(title)),

    // The logo in the sidebar.
    locate(loc => {
      set align(right)

      // Logo.
      style(styles => {
        if typst-logo == none {
          return
        }
  
        let img = image(typst-logo.path, width: 1.5cm)
        let img-size = measure(img, styles)
        
        grid(
          columns: (img-size.width, 1cm),
          column-gutter: 16pt,
          rows: img-size.height,
          img,
        )
      })
      
    }),
    
    // The main body text.
    {
      set par(justify: true)
      body
      v(1fr)
    },
  

  )
}


#show: PrettyPDF.with(
  title: "Nocturnal Cinema",
  typst-logo: (
    path: "\_extensions/nrennie/PrettyPDF/logo.png",
    caption: []
  ), 
)



#figure([
#box(image("img/ascenseur.jpg"))
], caption: figure.caption(
position: bottom, 
[
#emph[Ascenseur pour l’échafaud] (Louis Malle, 1958)
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


#block[
#link("https://mroberts.emerson.build/")[Martin Roberts] #link("mailto:martin_roberts@emerson.edu")[] \
#link("https://emerson.edu/academics/academic-departments/visual-media-arts")[Department of Visual & Media Arts] \
#link("https://emerson.edu")[Emerson College] \
#link("https://theurbannight.files.wordpress.com/2022/03/book-of-abstracts.pdf")[Media & The Night Conference] \
McGill University \
18-19 March 2022

]

#horizontalrule

#quote(block: true)[
Le cinéma s’est approprié la nuit pour la réinventer et, depuis, notre perception n’est plus la même. Difficile de contempler Shanghai ou New York sans penser à #emph[Blade Runner];. Plaisirs de noctambules, nuit des truands, des dealers et des paumés, nuit de rêve ou quotidien des travailleurs nocturnes… , par sa magie, le septième art s’est emparé de la nuit pour en faire un personnage à part entière.
]

#block[
Cinema has appropriated night in order to reinvent it, and since then our perception of it has not been the same. It’s hard to look at Shanghai or New York without thinking about #emph[Blade Runner];. The pleasures of nocturnal flâneurs; the night of crooks, dealers, and down-and-outs; the night of dreams or the everyday night of workers… By its magic, the seventh art has taken hold of the night in order to turn it into a character in its own right.

]
#quote(block: true)[
– @gwiazdzinski2016[: 63];.
]

#quote(block: true)[
\[L\]a nuit suggère, elle ne montre pas. La nuit nous trouble et nous surprend par son étrangeté; elle libère des forces en nous qui, le jour, sont dominées par la raison. . . . J’aimais les prodiges de la nuit que la lumière contraignait à se manifester; il n’existe pas une nuit absolue.
]

#block[
The night doesn’t show, it suggests. It disturbs and surprises us by its strangeness; it triggers impulses in us that, during the day, are dominated by reason. . . . I loved the wonders of the night that light forced to manifest themselves; absolute night does not exist.

]
#quote(block: true)[
– Brassaï, feuillet inédit, archives Gilberte Brassaï, no date (Exposition «Brassaï», Centre Georges Pompidou, 2000).
]

#quote(block: true)[
Black and white are, for me, cinema’s most beautiful colours.

– Rainer Werner Fassbinder @misek2010[: 83];.
]

#horizontalrule

== Avant-Propos / Preamble
<avant-propos-preamble>
I’d like to start with a brief disclaimer about what I am trying to do in this paper, and—just as importantly—what I am #emph[not] trying to do. As many people here will no doubt be already aware, there has existed for some time now a voluminous and highly specialized body of literature on the genre of #emph[film noir];, and on the postwar movement in French film known as the #emph[nouvelle vague] or New Wave. While I have no pretensions to adding to that literature, its existence does not mean that everything there is to say on these subjects has already been said. Maybe I’ve just been watching too many heist movies lately, but what I am interested in doing is to try—under cover of darkness, obviously—to break open the constrictive generic and auteurist #emph[coffres-forts] in which cinema has been locked away for decades by introducing a different paradigm that I call #emph[nocturnal cinema];. While the night has figured prominently in cinema from its earliest origins, by nocturnal cinema I am referring to a more specific corpus of films in which night is not just a temporal backdrop for narrative realism but is foregrounded as an aesthetic, thematic, stylistic, and symbolic element in the films in question. The paradigm of nocturnal cinema, I want to suggest, opens up the possibility of conceptualizing alternative histories of cinema that treat it not as a discrete object of study but position it within a broader cultural spectrum of media and artistic practices. As such, it may serve as a prototype for other new ways of thinking about the history of cinema.

With that said, let us begin, as one must, with Melville.

== Pigalle
<pigalle>
This sequence from #emph[Bob le flambeur] provides a succinct example of a particular kind of cinematic cultural mythology that was already in place when Melville’s film was released in 1956: a set of associations involving criminal activity, music, and the urban night, originating in the cinematic appropriation of popular crime fiction, that in the late 1940s came to be known as #emph[film noir];. The emergence of this mythology in the late-1930s films of Marcel Carné, and over subsequent decades in the films of Jules Dassin, Jacques Becker, Jean-Pierre Melville, Louis Malle, and Édouard Molinaro, followed by the #emph[nouvelle vague] films of Godard, Truffaut, Chabrol, and others, is the subject both of the present paper and a related project I am currently working on, a cinematic compilation album titled #emph[Ciné-Jazz];.

#block[
]
For reasons of time, I will limit myself here to the work of Édouard Molinaro, which has been overshadowed by the better-known examples of Louis Malle’s celebrated collaboration with Miles Davis on #emph[Ascenseur pour l’échafaud] (1958), Godard’s #emph[À bout de souffle] (1960), and others. The series of films released by Molinaro in the late 1950s that includes #emph[Le dos au mur] (1958), #emph[Des femmes disparaissent] (1959, and #emph[Un témoin dans la ville] (1959), embody the cinematic chronotope of urban crime, jazz, and the night. Collectively, they provide a case study in a larger genre that I would like to call #emph[nocturnal cinema];. I want to explore here some of the key characteristics of this nocturnal cinema, as manifested in French #emph[film noir] and its legacy in the #emph[nouvelle vague] or New Wave.

== Nuits Monochromes
<nuits-monochromes>
As a quintessentially nocturnal experience of urban modernity, cinema is almost organically related to the night; as Luc Gwiazdzinski has observed,

#quote(block: true)[
Du noir de la pellicule à l’obscurité de ses salles, le cinéma entretient un rapport quasi physique avec la nuit. Rien ne semble pouvoir échapper à l’emprise de la nuit. Il est souvent plus difficile d’apprécier un film en journée: même projeté dans une salle obscure, le film perd de son intensité et à la sortie, le mystère et la magie s’estompent trop vite (2016: 62).
]

But if the urban experience of watching movies has historically taken place in nocturnal darkness, the nocturnal city itself has been a subject of predilection for cinema since its inception; consider, for example, the early movies of Edison cameraman Edwin Porter, of the dazzling lights of the #link("https://youtu.be/Q5m6joTlnqA")[Pan-American exhibition] or #link("https://www.youtube.com/watch?v=NqDtG3dcxPs")[Coney Island] at night. There is a residual sense of wonder, what David Nye calls the electrical sublime, in the nocturnal cityscapes of Molinaro and other filmmakers of his time, the "magie" of the night alluded to by Gwiadzdinski; but I would argue that by the 1950s this had been displaced by a deep ambivalence about the night as a space both of temptation, of opportunity for financial and erotic gain unavailable in the mundane light of day, but also a space of danger, or more accurately dangerous liaisons that lead to the downfall of those who embrace them.

The urban night is also the privileged chronotope of #emph[film noir];, whether in its American, French, or British incarnations, and that night, with its deserted streets, its neon-drenched demi-monde of bars and cabarets, is the pre-eminent setting for shady goings-on of all kinds, from jewel heists to prostitution to drug deals to the disposal of bodies. But while the night provides the backdrop to such activities in #emph[film noir];, from Fritz Lang’s #emph[The Woman in the Window] (1944) to Jules Dassin’s #emph[Night and the City] (1950), it takes on a particularly luminous resonance in the French cinema of the 1950s, from the films of Melville, as we have seen, to Louis Malle’s #emph[Ascenseur pour l’échafaud] (1958), with its famous sequence of Jean Moreau prowling the Parisian streets in search of her missing lover, accompanied by Miles Davis’s muted trumpet.

Although less common in #emph[film noir] than is often assumed, jazz soundtracks are a key component of nocturnal cinema, in part because of the music’s own associations with nocturnal entertainment. Not only Miles Davis, but many other American jazz musicians performed in Paris in the late 1950s, including Donald Byrd, Thelonious Monk, and Art Blakey, in addition to musicians already based there such as René Urtreger, Franco-American Barney Wilen, and Algerian-born Martial Solal. Various permutations of these musicians were tapped to write soundtracks for French films: Art Blakey’s Jazz Messengers for Molinaro’s #emph[Des Femmes disparaissent] and Roger Vadim’s #emph[Les Liaisons dangereuses];; Monk also for #emph[Les Liaisons dangereuses];; Barney Wilen and Kenny Dorham for #emph[Un témoin dans la ville];; Martial Solal for Godard’s #emph[À bout de souffle];.

#block[
]
It is, however, in the nocturnal cinema of Édouard Molinaro that the aesthetic resonance of the urban night reaches its fullest expression; so tangible does its presence become that one would be hard put to find a better example of Gwiazdzinski’s point that cinema has transformed the night into a character in its own right. While not all the action of #emph[Le dos au mur] and #emph[Un témoin dans la ville] takes place at night, so rare are the glimpses of daylight that one could easily assume that both films take place entirely after dark. In #emph[Des femmes disparaissent];, even those fleeting glimpses of daylight disappear in a film whose setting is exclusively nocturnal.

#emph[Le dos au mur] opens with a staple noir motif: the disposal of a body. Late at night, somewhere on the outskirts of Paris, a man wearing the signature trenchcoat and fedora exits a mansion and drives in to the city and enters a first-floor apartment, where to our surprise the murder has already taken place. Turning off a still-running shaver in the bathroom, the man wraps up the body of the dead man lying on the floor in a large rug and carries it to his car. He then drives to a nearby construction site and laboriously disposes of the body by mixing concrete, hoisting the carpet-wrapped body up onto scaffolding, and entombing it in a large wall that, it later emerges, happens to be adjacent to his office building. The rest of the film is an extended flashback that explains the circumstances that led up to this bizarre opening over the preceding three months.

In #emph[Des femmes disparaissent];, a man stumbles upon a human-trafficking network run by an organization of businessmen that enshares young women with promises of jet-set lifestyles, after his fiancée becomes one of its latest would-be recruits. Captured by one of the organization’s henchmen, he manages to escape with his fiancée only for the couple to be recaptured after being betrayed by one of the organization’s accomplices. The film culminates in an extended shootout at the organization’s country mansion, the liberation of the abducted women, and our hero delivering a richly-earned beating to the organization’s leader.

#emph[Un témoin dans la ville] starts out with not one but two staged suicides: a man who murders his mistress by pushing her off a train escapes prosecution by claiming she committed suicide, only to become himself the victim of a staged suicide when he is murdered one night soon afterwards by the woman’s ex-husband, Ancelin. As Ancelin slips out of the first’s house, however, he runs into a driver for a fleet of radio taxis waiting outside, whom the man he has just murdered had ordered earlier. The rest of the film depicts Ancelin’s constantly frustrated efforts to eliminate the witness, and ultimately his own pursuit by the fleet of taxi drivers and the police. The pursuit culminates at the Jardin d’Acclimatation in the Bois de Boulogne and includes eerie cutaways of startled birds and animals.

The three films share many of the signature elements of #emph[film noir];: perfect crime gone wrong; trench-coated, fedora-wearing male protagonists; alluring female protagonists; expressionistic lighting with unmotivated shadows; deep focus; and in two of the films, a jazz soundtrack. All three films make extensive use of musical cues to underscore their nocturnal sequences: #emph[Le dos au mur] opens with Richard Cornu’s conventionally melodramatic orchestral score, although the rest of the sequence unfolds in a tense silence. In #emph[Un témoin dans la ville];, after the initial trauma of the train sequence, the relaxed down-tempo of Barney Wilen’s saxophone suggests a return to some semblance of normality as the murderer arrives at the public prosecutor’s office to confirm the dismissal of his case as a #emph[non-lieu];. By contrast, Art Blakey’s heartbeat-like drum figure at the opening of #emph[Des femmes disparaisent] creates a sense of ominous suspense from the outset.

But it is their characterization of the urban night that accounts for much of the films’ aesthetic appeal. In each, the night is a space not of total darkness but partial illumination, lit by the myriad light sources of the nocturnal city: the glow of street lights and the neon signs of bars, cafes, and advertisements; floodlit buildings and monuments; the dazzling displays of movie theater marquees; the mesmerizing patterns of automobile headlamps; even (in #emph[Le dos au mur];) portable flashlights. The term #emph[incandescent] refers to the emission of light by an object as a result of being heated, derived from the Latin verb #emph[incandescere];, to glow white. From this standpoint, Molinaro’s film can be described not just as a nocturnal but an incandescent cinema, its darkness illuminated by lights that burn with white-hot intensity.

#block[
]
This aesthetics of incandescence is not unique to Molinaro’s films, and is in fact one of the historical particularities of the city of Paris itself. Popularly known as the City of Light, or #emph[ville lumière];, since the late seventeenth century, Paris was one of the first European cities to install a system of street lighting, but not for aesthetic or commercial purposes. As is well known, the measure was made at the instigation of the police in response to a rising nocturnal crime wave:

#quote(block: true)[
Gilbert Nicolas de la Reynie, alors nommé tout premier lieutenant général de police de Paris, en mars 1667, décida d’enrayer la criminalité grandissante dans la ville en mettant en place un éclairage public dans les rues, ruelles et impasses afin de dissuader les rôdeurs et criminels d’agir en tout impunité. Les premières lanternes d’éclairage public sont ainsi installées dans la ville de Paris et quelques mois après l’ordonnance, 2,736 lanternes à mèche charbonnée sont posées et 912 rues éclairées dans Paris (#link("https://breves-histoire.fr/thematique/ville-lumiere/")["Ville-lumière: vestiges insolites"];, #emph[Brèves d’Histoire];, no date).
]

Two and a half centuries later, a young Transylvanian journalist named Gyula Halász who had moved to Paris in 1924 became entranced by the nocturnal incandescence of the #emph[ville lumière] and its nightlife, and began documenting them in photography and writing. The collection of sixty black-and-white photographs of the city assembled in his 1932 book #emph[Paris de nuit] (1932), under the pseudonym of Brassaï (derived from the town of his birth, Brassó, in what was then Hungary), have since become an inseparable part of the city’s visual iconography, available from the postcard stands of countless newspaper kiosks and museum gift shops. The impact of Brassaï’s luminous images of nocturnal Paris on the stylization of the night in French #emph[film noir] several decades later is readily apparent, nowhere more so than in the films of Édouard Molinaro. Their most obvious element in common is their monochromatic nature, at a time when black and white cinematography was coded either as a signifier of neorealism or a stylistic element of #emph[film noir] and horror movies, in opposition to the garish Technicolor of Hollywood musicals. While in Brassaï’s photography the interplay of shadows and light serve a primarily aesthetic purpose, however, in Molinaro’s films it takes on a more specifically symbolic dimension, as a metaphor for the equally high-contrast moral world that the characters inhabit. #emph["Quelle nuit!"];, the characters repeatedly exclaim in #emph[Le dos au mur];, referring not just to the fact that it’s dark out but to the disturbing events taking place within it. In this world, light represents the ontological security of the social order and its institutions, literally shining the light on criminal activity and driving back the forces of darkness.

In the climactic sequence of #emph[Un témoin dans la ville];, the criminal is pursued into the Jardin d’Acclimatation by a a driver, by whom he is shot but then manages to overpower. Climbing over a gate, he appears to have eluded his pursuers yet again, only to be suddenly dazzled by the headlights of a fleet of encircling police cars. Finally exposed, he collapses under a hail of police bullets, and the film’s closing long shot shows his prone body spotlighted by the vehicles’ headlights as the police close in. No longer concealed by nocturnal shadows, the criminal has finally been brought into the light of justice. FIN.

#block[
]
While the monochromatic nocturnal cityscapes of Molinaro’s films are indebted to Brassaï’s mythologization of nocturnal Paris, however, they also add two crucial cinematic elements to it: motion and music. Other than murder, double-crossing, and abduction, one of the most prominent activities in Molinaro’s nocturnal films is driving: more specifically, night driving. Molinaro’s characters spend considerable time driving back and forth around the city, frequently in pursuit of one another. Collisions are common: cars are as much weapons as revolvers, and can be used to take down fleeing witnesses, or simply crashed into the vehicles of escaping criminals. The entire narrative of #emph[Un témoin dans la ville] revolves around a fleet of radio taxis, a historical novelty in the late 1950s that motivates the film’s extended car-chase sequences when the entire fleet is mobilized in pursuit of the murderer of the taxi driver. These taxis and other cars all carry unseen cameras, of course, and as such they become vehicles for the films’ extended tracking shots of the illuminated cityscape, of which they themselves are an integral part. Close-ups of headlights being switched on before cars speed away are ubiquitous; driver POV and rear-window shots show drifting bokeh patterns of blurred light, heightened during chase sequences.

The centrality of the automobile as a vehicle for exploring the night is far from limited to Molinaro’s films, of course; even in scenes of noctambulation, such as Jeanne Moreau’s celebrated #emph[ballade] in #emph[Ascenseur pour l’échafaud];, she spends most of her time staring at cars in the hope of spotting her missing lover.

The jazz soundtracks of Molinaro’s films can be seen as homologous (in Paul Willis’s sense) with their visual elements. For all its experimentation with chromatic scales, in its visual representations jazz has always been a monochromatic music: the entire iconography of bebop prior to the 1970s consists of black-and-white photographs of Bird, Billie Holiday, Monk, Miles, Coltrane, and many more; the titles of jazz tunes are littered with references to shadows and light; while the black/white opposition even extends to the dynamics of race in the history of the music itself, in the systemic harassment of and often violence against black musicians by white law enforcement; and on the other hand the embrace of Harlem jazz by Norman Mailer’s hipster "white negro".

The nocturnal cityscape takes on a very different look in the extended chase sequence from Louis Malle’s comedy #emph[Zazie dans le métro] (1961), which as one critic has noted is a far cry from the dark mood and themes of #emph[Ascenseur pour l’échafaud] two years earlier. By now the #emph[film noir] car chase sequence has already become an object of parody, and in contrast to the monochrome of Malle’s earlier film, his use of Kodak’s Eastmancolor stock for #emph[Zazie] looks suddenly garish and enhances its cartoonlike look. Much the same can be said of Jacques Météhen’s hectic jazz score. Yet even in the mode of pastiche, the sequence again provides an animated portrait of #emph[Paris nocturne];.

#block[
]
== Night Driving
<night-driving>
Over the decade from the mid-1950s to the mid-1960s, the stylistic elements of a nocturnal cinema gradually come into view in French #emph[film noir] and the #emph[nouvelle vague] like a developing Brassaï photograph. By the time we get to #emph[Le départ] (1967), the photograph is complete. Directed by Polish auteur Jerzy Skolimowski and shot in Brussels rather than Paris in this case, the film stars #emph[nouvelle vague] icon Jean-Pierre Léaud as a car-obsessed hairdresser and a score by Polish jazz musician Krzysztof Komeda. As early as the opening credits, the picture is in place: the black-and-white cinematography, even in 1967; the jazz; and the car, shot from the rear of a preceding vehicle and transformed from a mundane taxi into a flashy white Porsche, plunging towards us through the incandescent swirl of streetlights. From Melville to Skolimowski, then, the cinematic romance of the nocturnal city as a space of temptation and danger.

#block[
]
== Nocturnal Panoramas
<nocturnal-panoramas>
In the tradition of Baudelaire and Walter Benjamin’s archetypal painter of modern life, the #emph[flâneur];, numerous books have been written about the experience of exploring the city after dark by walking around it. From Surrealist #emph[flâneurs] to Situationist psychogeographers and their post-millennial descendants, there remains a pedestrian insistence (in every sense of the term) that the city is most profoundly experienced #emph[on foot];. The psychogeographic literature on the urban night reproduces this ideology in its romanticization of #emph[noctambulation];, or wandering the city at night. Cinema, for its part, is densely populated both by diurnal and nocturnal #emph[flâneurs/-euses];, from Jeanne Moreau in #emph[Ascenseur à l’échafaud] and Antonioni’s #emph[La Notte] to David Hemmings in #emph[Blow Up];. Yet the nocturnal cinema of Édouard Molinaro shows that the cinematic experience of the urban night has taken place as much from behind the wheel as on sidewalks, and typically involves more goal-oriented activities than psychogeographic research. I have come across only one psychogeographic film that involves driving rather than walking, Chris Petit and Iain Sinclair’s Ballardian homage to the M25 motorway, #emph[London Orbital] (2002), but a growing number of recent films involve exploring the city by night from a moving vehicle (Jonathan Glazer’s science-fiction film #emph[Under the Skin] (2012) comes to mind). In the postmodern megacities of the twenty-first century, it is more often from the freeway, as passengers or drivers, that we experience, and marvel at, the nocturnal panoramas of Los Angeles, Tokyo, Montréal, and the Ville Lumière itself. While the automobile arguably offers a more practical way of navigating such extended urban spaces, however, it also does more than this: viewing the panoramic nocturnal cityscape scrolling past through the frame of a car windshield or window transforms it into a cinematic experience; it feels like watching a movie. Films such as the aptly-titled #emph[Drive] (2011) explicitly play on this cinematic dimension of night driving, but it is equally ubiquitous in contemporary videogames and music videos. Collectively, they attest to the continuing ambivalence about the nocturnal city as a space of libidinal excess and dangerous liaisons.

#horizontalrule

#bibliography("https:\/\/api.citedrive.com/bib/aa54ee25-d1a4-4838-8eb0-848e54d75b38/references.bib?x=eyJpZCI6ICJhYTU0ZWUyNS1kMWE0LTQ4MzgtOGViMC04NDhlNTRkNzViMzgiLCAidXNlciI6ICIxMTkxMiIsICJzaWduYXR1cmUiOiAiNTY3MDIxZDJkYzBkMTM3ZTUxODFlOTVkN2Q4ZDk3ZDk3Mzk2ODM3YzQ2MWJiMDhhYWFhYWJkZjRjOTk5YWQxZSJ9")

