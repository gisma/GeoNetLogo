; Base model is copyrighted 2015 Grider, R. and U. Wilensky.
; Used model snippets are from voronoi, mouse example, vision cone example, wealth distribution Copyright all U. Wilensky
; Copyright for enhancing and compiling the model and the Info Text: Rieke Ammoneit & Chris Reudenbach 2020
; See Info tab for more copyright and license.

; there are quite a lot of functions disabled
; voronoi ask patches [set pcolor startarea]
; rev-voronoi ask patches[set pcolor currentcolor]

; define turtles
breed [ walkers walker ]

; define turtles and patches specific variables
walkers-own [ goal walkable]
patches-own [ popularity streets obstacle startarea currentcolor]

; define global (observer) variables
globals [
  roads
  visible-routes
  gini-index-reserve
  lorenz-points
  old-gray-patches
  available-colors
]

; setup procedure carried out once
to setup
  clear-all
  create-colorlist
  set vis-pop false
  ask patches [ set pcolor green
    set obstacle 0
    set popularity 0
    set old-gray-patches 0
  ]

  ; call the experiment setup procedure
  make-experiment
ask patches[
      set currentcolor pcolor
    ]
 ; if no experiment is choosen stop
  if selected-experiment = "none" [
    if message [user-message (word "Es wurde kein Szenario gewählt?!\n Zähle jetzt Schafe...")]
      ask  n-of n-walker patches [sprout-walkers 1 [
        set color white
        set size random 10
        set shape "sheep"
      ]
    ]
  ]

  ; finsihed so reset ticks
  ; if you want to calculate a lorenz curve you need to uncomment this call
  ;update-lorenz-and-gini

  reset-ticks
end

; procedure that controls the model run
; adapted from the original paths model
to go

  colorize-patches
  ; main procedure that rules the movement
  move-walkers

  ;; if you want to calculate a lorenz curve you need to uncomment this call
  ;update-lorenz-and-gini

  tick

  ;; if you do not want to use the Behavoiur Space you may use the next to calls to dump out result files
  ;if ticks = 4000 [
  ;  export-world (word "results/results " behaviorspace-experiment-name behaviorspace-run-number ".csv")
  ;  export-plot "number of patches"  (word "results/results " behaviorspace-experiment-name behaviorspace-run-number "_number-of-patches-per-decentile.csv")
  ;]
end

;##################################################################
; basic model slightly adapted from 2015 Grider, R. and U. Wilensky
;##################################################################
; procedure that calculate the attraction of a patch
; adapted from the original paths model where gray above a certain limit was set to paths
to become-more-popular
  set popularity popularity + 1
  ; if the increase in popularity takes us above the threshold, become a route
  ; current threshold is 1 times by a turtle
  if pcolor != orange [
    if obstacle != 1 [
      if popularity >= pop-lowlimit [ set pcolor gray ]]
  ]
end

; procedure to control the movement of walkers
; adapted from the original paths model
; the different experiments are treated
; the setup of goals has become reason driven
to move-walkers
  ask walkers [
    if patch-here = goal [
      if selected-experiment = "street-goals" [set goal one-of patches with [streets = 1]
      if show-goal [   ask goal [set pcolor yellow] ]
      ]
      if selected-experiment ="orange-goals"
      or selected-experiment ="Y"
       or selected-experiment ="square"
       or selected-experiment ="houseOfSantaClaus" [set goal one-of patches with [pcolor = orange]]
      ]
      walk-towards-goal
  ]
end

; procedure to control the popularity of patches,
; the destination of the next walkes step and the avoidance of obstacles
; avoidance of obstacles has been added
to walk-towards-goal
  ask patch-here [ become-more-popular ]
  face best-way-to goal
  ifelse line-not-cone
  [avoid-patches-line]
  [avoid-patches-cone]
  fd 1
end



; ####################################################################
; avoiding obstacles (2 different approaches so far)
; ####################################################################
; controls avoiding  barriers by line of sight and storing walkable patches to
; turtle own list
to avoid-patches-line
    ;let dir random-normal 0 1
  ; if walker is below the visual range of talking care
  ; it turns by one degree and samples the walkable patches
  while [line-of-sight < walker-vision-dist][
    ; ifelse dir < 0 [rt 12.5]
                    lt 1 ]
  ; nobody is removed from list
  set walkable remove nobody walkable
  face one-of walkable

end
; reporter of the walkable list in a giben line of sight
to-report line-of-sight  ;; walker procedure
  let dist 1
  let a1 [obstacle] of patch-here
  let last-patch patch-here
  set walkable []
  while [dist <= walker-vision-dist] [
    let p patch-ahead dist
    set walkable lput (patch-ahead dist ) walkable
    if p != last-patch and p != nobody [
      let a2 [obstacle] of p
      if a1 < a2
        [ set dist walker-vision-dist ]
      set last-patch p
    ]
    set dist dist + 1
  ]
  report length walkable

  ;]
end

; this procedure adapts the forward looking example of obstacles avoidance as presented by
; Vision Cone example of the Netlogo Lib in addition some ideas are taken from
; Thomas Christy at Bangor University 2009 and modified by William John Teahan
; http://files.bookboon.com/ai/index.html
; https://files.bookboon.com/ai/Obstacle-Avoidance-1.html
; found by google search "netlogo obstacle avoidance" page 3
to avoid-patches-cone
 ; visualisation of cone of sight
 ; recolor all cone patches to the original colors
 ; we have to do so because otherwise the last cone will remain
 ask patches with [pcolor = sky]
  [ set pcolor green ]
 ask patches with [pcolor = pink]
  [ set pcolor red ]
  ask patches with [pcolor = cyan]
  [ set pcolor gray ]
 ; if visualisation of cones ist true
 ; color the cone depending on the underlying patch classes
 if vis-vision [
  ask patches in-cone walker-vision-dist walker-v-angle [
    if pcolor = green
    [ set pcolor sky ]
    if pcolor = gray
    [ set pcolor cyan]
    if pcolor = red
    [ set pcolor pink ]
  ]
]

; start of obstacle avoidance
; count patches in cone that are obstacles if there is at least one obstacle
; turn 12.5 degrees
; do this until there is no obstacle in cone
while [count patches in-cone walker-vision-dist walker-v-angle with [obstacle = 1] > 0]
 [ rt 1 ]

 ;  error workaround for touching the boundary of world that produces the "nobody" error
 ; we just check the patch in front and only if it is not nobody we head on
 let try  one-of patches in-cone walker-vision-dist walker-v-angle with [obstacle != 1]
  if try != nobody

 ; turn to one of the patches in the cone WITHOUT (!=1) an obstacle
  [face one-of patches in-cone walker-vision-dist walker-v-angle with [obstacle != 1]]

  ; last check if there is an obstacle
  ; step 1 backwards and turn 90 deg
  if [obstacle] of patch-ahead 1 = 1
  [bk 1 lt 90]

end

;#########################################################
; reporter for analysis and decision
;#########################################################
; procedure that calculate and perfom the decison  of the best direction
; adapted from the original paths model
to-report best-way-to [ destination ]
  ; of all the visible route patches (=gray), select the ones
  ; that would take me closer to my destination

  let visible-patches patches in-radius walker-vision-dist
  ;let visible-routes visible-patches with [popularity >= pop-lowlimit]
  ifelse not max-pop [set visible-routes visible-patches with [
     popularity >= pop-lowlimit]
   ;print "1"
  ]
   [set visible-routes visible-patches with-max [ popularity]

  ]
  ;print [popularity] of visible-routes
  let routes-that-take-me-closer visible-routes with [
    distance destination < [ distance destination - dist-diff] of myself
  ]
  ; decision
  ifelse any? routes-that-take-me-closer [
    ; from those route patches, choose the one that is the closest to me
    report min-one-of routes-that-take-me-closer [ distance self ]
  ] [
    ; if there are no nearby routes to my destination
    report destination
  ]
end

; checks if new paths patches are created if not stop simulation
; according to
to-report stopitnow
  let stopit false
  let resolution abs(min-pxcor) + abs(max-pxcor)

  if old-gray-patches = count-of-trampling and  ticks > (100 / n-walker * resolution ) [set stopit true]
  report stopit
end
; reports number of gray patches
to-report count-of-trampling
  report  count patches  with [popularity >= pop-lowlimit]
end

; reports number of patches with the pop-lowlimit value
to-report count-of-popularity-minimum
  report  count patches  with [popularity = pop-lowlimit  ]
end

; reports teh average popularity value of all patches
to-report popularity-average
let psum sum [popularity] of patches with [popularity >= pop-lowlimit]
let pcount count patches with [popularity >= pop-lowlimit]
report psum / pcount
end

;reports the maximum value of popularity
to-report popularity-maximum
let psum sum [popularity] of patches with-max [popularity]
let pcount count patches with-max [popularity]
  report psum / pcount
end

; reports the Gini Coefficient
to-report gini-05
  report  gini-index-reserve / count-of-trampling
end

; reports number of patches that are used without noticed to be popular
to-report count-of-trampling-without-popularity
   report count patches  with [popularity < pop-lowlimit and pcolor != green and pcolor != orange]
end


; function reports a list of the popuklarity values of all patches >= pop-lowlimit
to-report spop
  report sort [popularity] of patches with [popularity >=  pop-lowlimit]
end


; #########################################################
; colors and paints
; #########################################################
;; procedure to colorize the popularity
;; a linear approach from lowliomit to current max value is applied
to   scale-p
  set vis-vision false
  if ticks > 10 [
  let pmax max [popularity] of patches
  ;if pmax < pop-lowlimit [set pmax pop-lowlimit + pop-lowlimit]
  ;print pmax
  ask patches with [pcolor != orange and pcolor != green and pcolor != red]
  [ set pcolor scale-color magenta popularity pop-lowlimit pmax ]
  ]
end



; rescales the color of patches if vis-pop is used
to colorize-patches
  set old-gray-patches count-of-trampling
  ; for runtime scaling and graying the popularity patches
  ask patches with[obstacle = 1][set pcolor red]
  ifelse not vis-pop [ask patches with [popularity >= pop-lowlimit and pcolor != green and pcolor != orange and pcolor != red] [set pcolor gray]]
  [scale-p]
  ask patches[ if pcolor != green [
    set currentcolor pcolor ]
    ]
end

; creates an list of numbers to colorize the voronoi patches
to create-colorlist
  set available-colors shuffle filter [ c ->
    (c mod 10 >= 3) and (c mod 10 <= 7)
  ]  n-values 140 [ n -> n ]

end

; helper function to make patches with a defined condition (circle distance) also gray
; used in create-roads
to make-patch-gray [p]
  ask p [ set pcolor gray]
end

; provides an simple way to draw new facilities
to draw-world-items
  while [mouse-down?] [
    create-turtles 1 [
      setxy mouse-xcor mouse-ycor
      ask patches in-radius line-width [ set pcolor read-from-string p_color
        if pcolor = red [set obstacle 1
                         set streets 0]
        if pcolor = gray [set obstacle 0
                         set streets  1
                         set popularity roads-pop
        set popularity roads-pop]
        if pcolor = green [set obstacle 0
                         set streets  0
                         set popularity 0]
      ]
      die
    ]
    display
  ]
end

;; this procedure recomputes the value of gini-index-reserve
;; and the points in lorenz-points for the Lorenz and Gini-Index plots
to update-lorenz-and-gini
  let sorted-popularity sort [popularity] of patches with [popularity >=  pop-lowlimit]
  let total-popularity sum sorted-popularity
  let popularity-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []

  ;; now actually plot the Lorenz curve -- along the way, we also
  ;; calculate the Gini index.
  ;; (see the Info tab for a description of the curve and measure)
  repeat count patches with [popularity >=  pop-lowlimit] [
       set popularity-sum-so-far (popularity-sum-so-far + item index sorted-popularity)
    set lorenz-points lput ((popularity-sum-so-far / total-popularity) * 100) lorenz-points
    ;print lorenz-points
    set index (index + 1)
    set gini-index-reserve
      gini-index-reserve +
      (index / count patches with [popularity >=  pop-lowlimit]) -
      (popularity-sum-so-far / total-popularity)
  ]
end

; #####################################################
; create experiments
; #####################################################
; this procedure creates some static road systems
; road width and geometry typ is defined by the GUI
to create-roads
   if preset-roads = "triangle" [
    set roads patches with [pxcor = -20 or pycor = 20 or pycor = pxcor - 2 ] ]
   if preset-roads = "square" [
    set roads patches with [pxcor = -20 or pycor = 20 or pxcor = 20 or pycor = -20] ]
   if preset-roads = "X" [
    set roads patches with [pxcor = pycor  or (-1 * pxcor) =  pycor ] ]
  ask roads [ make-patch-gray patches in-radius road-width set pcolor gray]
  set roads patches with [pcolor = gray]
  ask roads[
    set popularity roads-pop
    set streets 1 ]
  display
end

; this procedure creates some static road systems
; geometry is defined by the GUI
to make-experiment

    ; triangle
    if selected-experiment = "Y" [
    ; not rotated
    ;https://www.triangle-calculator.com/de/?what=vc&a=-40&a1=-40&3dd=3D&a2=0&b=0&b1=29.2825&b2=0&c=40&c1=-40&c2=0&submit=Berechnen&3d=0
    ;[-40 -40] [0 29.2825]  [40 -40]
    ;slightly rotated
    ;https://www.triangle-calculator.com/de/?what=vc&a=-40&a1=-40&3dd=3D&a2=0&b=4&b1=29&b2=0&c=35&c1=-43&c2=0&submit=Berechnen&3d=0

    ;recolorize remaining orange patches back to green
    ask patches with [pcolor = orange] [set pcolor  green]
    ;define goal patches and make them orange
    ask patches at-points [ [-40 -36] [4 27] [35 -43]] [ set pcolor orange]
    ; create walkers according to the settings
    ask  n-of n-walker patches [sprout-walkers 1 [
      set goal one-of patches with [pcolor = orange]
      set size 5
      set color black
      set shape "stud_tri"
      set color first available-colors
      set available-colors butfirst available-colors
      ]
    ]
    ask patches[
      set startarea [color] of min-one-of walkers [distance myself]
    ]

    ask walkers [set color black]
        if message = true [user-message (word "A predefined triangle in the form of orange corner points was created. \n"
      "With the draw-world-items button and the color selection orange, further destinations can be set.\n"
      "The colour gray creates roads, green creates meadows and red creates barriers.")  ]
  ]

  ; pentagon
  if selected-experiment = "houseOfSantaClaus" [
    ask patches with [pcolor = orange] [set pcolor  green]
    ask patches at-points [[-35 10] [-35 -40] [0 40]  [35 10] [35 -40]] [ set pcolor orange]

    ask  n-of n-walker patches [sprout-walkers 1 [
    if selected-experiment ="houseOfSantaClaus" [set goal one-of patches with [pcolor = orange]]
      set size 4
      set color 129
      set shape "stud-pent"
      set color first available-colors
      set available-colors butfirst available-colors
      ]
    ]
    ask patches[
      set startarea [color] of min-one-of walkers [distance myself]
    ]

    ask walkers [set color black]
        if message = true [user-message (word "A predefined pentagon in the form of orange corner points was created.  \n"
      "With the draw-world-items button and the color selection orange, further destinations can be set.\n"
      "The colour gray creates roads, green creates meadows and red creates barriers.")  ]
  ]

  ; square
  if selected-experiment = "square" [
    ask patches with [pcolor = orange] [set pcolor  green]
    ask patches at-points [[-35 40] [-35 -40]  [35 40] [35 -40]] [ set pcolor orange]
        ask  n-of n-walker patches [sprout-walkers 1 [
    if selected-experiment ="square" [set goal one-of patches with [pcolor = orange]]
      set size 4
      set color 105
      set shape "stud-square"]
    ]
     if message = true [user-message (word "A predefined square in the form of orange corner points was created.  \n"
      "With the draw-world-items button and the color selection orange, further destinations can be set.\n"
      "The colour gray creates roads, green creates meadows and red creates barriers.")  ]
  ]

  ; a street szenario is choosen and strets are the only places for goals and turles to be born
  if selected-experiment = "street-goals" [
    if preset-roads != "none" [create-roads
      ; create walker and goals on structures (roads)
      ask  n-of n-walker roads [
        sprout-walkers 1 [set goal one-of patches with [streets = 1]
        if show-goal [ask goal [set pcolor yellow]]
        set size 4
        set color 45
        set shape "person student"
        ]
      ]
    ]
    if preset-roads = "none" [
        ask  n-of n-walker patches [
      sprout-walkers 1 [ set goal one-of patches
      if show-goal [ask goal [set pcolor yellow]]
        set size 4
        set color 45
        set shape "person student"
      ]
    ]
     if message [user-message (word "In the selection menu 'predifined-roads' NO predefined roads have been selected.\n"
        "Therefore either define NEW setup or draw roads manually NOW")]
    ]
  ]

  ; a free goal szenario is choosen (goals MUST be orange)
  if selected-experiment ="orange-goals" [
    if preset-roads != "none" [create-roads]
    ask n-of 4 patches with [pcolor = green][set pcolor orange]
    ask  n-of n-walker patches [sprout-walkers 1 [
    set goal one-of patches with [pcolor = orange]
      set size 4
      set color 45
      set shape "person student"]
    ]

    if message = true [user-message (word "Four random  orange patches were created.  \n"
      "With the draw-world-items button and the color selection orange, further destinations can be set.\n"
      "The colour gray creates roads, green creates meadows and red creates barriers.")  ]
  ]
end


; calls the help text
to help

  user-message (word "Quick Help\n"
"------------------------------experiments--------------------------------------------------"
  "|| selected-experiments || \n"
  "|| fixed geometry || (Y, square,  pentagon) spatial experiments with the orange dots as goals\n"
  "|| street-goals || (preset-roads)  experiments, with the roads creating walkers and goals only\n"
  "|| orange-goals || (orange patterns) experiment with free drawable orange patterns as goals\n"
  "--------------------------------------------------------------------------------------------------\n"
  "Check out draw-world-item for drawing gray,red,green and orange patches."
  "Note that these colors will be preset with the corresponding attributes\n"
  "---------------------------setup parameter----------------------------------------------\n"
  "|| n-walker || defines the number of walkers\n"
  "|| walker-vision-dist || defines the radius (in patches) a walker can analyse its sourounding\n"
  "|| walker-v-angle || defines the angle of the walkers vision cone when avoiding an obstacle\n"
  "|| max-pop || switch if true walkers will look for the patch with the maximum available popularity\n"
  "|| pop-lowlimit|| enter the minimum popularity value for a patch to be seen as an existing  path\n"
  "|| road-pop|| enter the popularity value for a street patch.\n"
"----------------------------------visualisation-------------------------------------------\n"
  "|| vis-vision || switch if true walkers show the cone of perception\n"
  "|| vis-pop || switch to scale during model runs the color of popularity\n"
  "|| show-goal || switch to show the goals during a street model run only\n"
  "|| message || switch to turn off GUI-related messages\n"
"----------------------------------Helpers---------------------------------------------\n"
  "|| export-scaled-view || exports the color-scaled view of the current state of the world as an png image to a file. The user has to provide a name.\n"
  "|| export-world || export the current state of the model to ancsv file. The name is automatically choosen.\n"
  "|| export-ditribution-plot || export the current distibution data to a csv file. The name is automatically choosen.\n"
  "|| drop lowlim pop || recolors the patches that are used less than the pop-lowlimit value to green\n"
  "|| rescale pop || recolors the  drop-lowlim patches back to the original color\n"
  "|| remove walkers || does it truly and forever!\n"

  )
end


; Base model is copyrighted 2015 Grider, R. and U. Wilensky.
; Used model snippets are from voronoi, mouse example, vision cone example, wealth distribution Copyright all U. Wilensky
; Copyright for the enhancing the model and the Info Text Rieke Ammoneit & Chris Reudenbach 2020
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
465
10
978
524
-1
-1
5.0
1
12
1
1
1
0
0
0
1
-50
50
-50
50
1
1
1
ticks
45.0

BUTTON
210
15
315
48
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
330
15
435
48
go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
0

SLIDER
10
115
155
148
walker-vision-dist
walker-vision-dist
1
200
19.0
1
1
NIL
HORIZONTAL

SWITCH
215
380
325
413
show-goal
show-goal
1
1
-1000

CHOOSER
15
410
145
455
p_color
p_color
"red" "orange" "grey" "green"
0

BUTTON
15
460
145
500
NIL
draw-world-items
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
80
155
113
n-walker
n-walker
1
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
10
150
155
183
walker-v-angle
walker-v-angle
1
360
1.0
1
1
NIL
HORIZONTAL

SWITCH
215
340
325
373
vis-vision
vis-vision
1
1
-1000

TEXTBOX
220
315
445
351
-------runtime visualisation-------
15
0.0
1

TEXTBOX
0
355
170
391
----------drawing----------
15
12.0
1

MONITOR
470
535
602
576
count pop >=  lowlimit
count-of-trampling
0
1
10

CHOOSER
15
545
145
590
preset-roads
preset-roads
"triangle" "square" "X" "none"
3

SLIDER
15
510
145
543
road-width
road-width
1
6
1.0
1
1
NIL
HORIZONTAL

SWITCH
330
380
440
413
message
message
0
1
-1000

CHOOSER
10
30
155
75
selected-experiment
selected-experiment
"none" "orange-goals" "street-goals" "Y" "houseOfSantaClaus" "square"
5

TEXTBOX
10
10
465
28
------ scenarios-------
15
0.0
1

SWITCH
330
340
440
373
vis-pop
vis-pop
1
1
-1000

SWITCH
10
185
155
218
max-pop
max-pop
1
1
-1000

INPUTBOX
10
220
80
280
pop-lowlimit
1.0
1
0
Number

INPUTBOX
85
220
155
280
roads-pop
2000.0
1
0
Number

MONITOR
470
625
600
666
average popularity
popularity-average
0
1
10

MONITOR
470
670
600
711
max-popularity
popularity-maximum
0
1
10

MONITOR
470
580
600
621
countl min pop
count-of-popularity-minimum
0
1
10

PLOT
615
535
975
710
number of patches
decentile
count
0.0
100.0
0.0
100.0
true
false
"" "ifelse popularity-maximum > pop-lowlimit\n[set-plot-x-range pop-lowlimit popularity-maximum]\n[set-plot-x-range pop-lowlimit (pop-lowlimit + 1)]\nset-histogram-num-bars 10"
PENS
"default" 50.0 1 -16777216 true "" "histogram spop"

BUTTON
330
50
435
83
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
195
105
315
138
remove walkers
die
NIL
1
T
TURTLE
NIL
NIL
NIL
NIL
1

BUTTON
195
185
315
218
rescale pop
let pmax max [popularity] of patches\nlet llim patches  with [popularity >= pop-lowlimit]\nask llim with [pcolor != orange  and pcolor != red]\n[ set pcolor scale-color magenta popularity pop-lowlimit pmax ]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
195
145
315
178
drop lowlim pop
\n   let llim patches  with [popularity <= pop-lowlimit]\n   ask llim with [pcolor != orange and pcolor != red][set pcolor green]\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
225
85
435
111
----------------Helpers---------------
12
0.0
1

BUTTON
325
145
450
178
export world
export-world (word \"export-world \" behaviorspace-experiment-name behaviorspace-run-number \".csv\")\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
325
185
450
218
export distribution
export-plot \"number of patches\"  (word \"export-plot \" behaviorspace-experiment-name behaviorspace-run-number \"_number-of-patches_decentile.csv\")
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
325
105
450
138
export scaled view
let pmax max [popularity] of patches\nlet llim patches  with [popularity >= pop-lowlimit]\nask llim with [pcolor != orange  and pcolor != red]\n[ set pcolor scale-color magenta popularity pop-lowlimit pmax ]\nask turtles [die]\nexport-view user-new-file \n\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
330
420
440
453
NIL
help\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
375
145
408
line-width
line-width
1
20
1.0
0.5
1
NIL
HORIZONTAL

SWITCH
10
285
155
318
line-not-cone
line-not-cone
1
1
-1000

SLIDER
10
320
155
353
dist-diff
dist-diff
1
25
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## _Wanderer, es gibt keine Straße, man macht seinen Weg zu Fuß<sup>*</sup>_ - Selbstorganisation von Trampelpfaden im Raum

Rieke Ammoneit und Chris Reudenbach 2020

## Einleitung

Räumlich agiernde Akteure müssen eben diese Räume nutzen und erschließen. Geschieht diese Nutzung regelmäßig entstehen Wege. Diese erleichtern und optimieren, sei es operationalisiert in Form von Strassen und befestigten Wegen oder ungeregelt als Trampelpfade, Steige o.ä., die Nutzung des erdgebundenen Raumes. Wo es keine regelhafte Infrastruktur gibt, geschieht dies durch gemeinschaftliche Nutzung oder um es mit dem spanischen Dichter Antonio Machado auszudrücken: _"Wanderer, es gibt keine Straße, man macht seinen Weg zu Fuß"_ [Machado 1917].

Folgt man Helbig (Helbing 1997) gibt es über die verschiedensten Disziplinen etwa der Stadtplanung, Verkehrsplanung, Archäologie, Geographie und Systemforschung ein breites Interesse an einem vertieften Verständis dieses Prozesses. Die Abstraktion solcher Systeme und die daraus abgeleitete Modellbildung kann theoretisch in der Selbstorganisation von Systemen und den daraus enstehenden ermergenten Strukturen begründet werden (Luhmann 1984). Einfach ausgedrückt enstehen Wege (wie Senor Machado sagt) durch die Wechselwirkung des Akteurs und seinen Bewegungsabsichten mit einem gegebenen Raum.

Gerade im planerischen Umfeld so z.B. bei Neu- oder Umplanunge von Stadtteilen, Parks etc. stellt sich häufig die Frage nach _guten_ oder _organischen_ Wegen [Molnar 1995, Schenk 1999 Schaber 2006]. Als _gute_ Wege sollen in diesem Kontext Wege bezeichnet werden, die von den Fussgängern und anderen Nutzern des Raumes angenommen und aktiv genutzt werden. Sind regulär solche Wege nicht verfügbar oder werden als nicht nützlich empfunden, enstehen häufig _wilde_ Wege also **Trampelpfade**, da Akteure diese Wege nutzen und durch eine unabgesprochene gemeinsame Bevorzugung häufig begangener Strecken diese zu einem Weg stabilisieren. 

In der vorliegenden Studie soll die spontane Entstehung von Trampelpfaden in einem einfachen isomorphen Raum untersucht werden. Insbsondere ob und inwieweit die Anazhl und die Wahrnehmungsfähigkeit der Akteure eine Auswirkung auf die entstehenden Wegemuster haben. Hierzu sind insbesondere Modellsysteme wie NetLogo geeignet, da sie einen einfachen softwarebasierten Zugang zur Programmierung Und Validierung agentenbasierter Prozesse im Raum bieten (Uhrmacher & Weyns 2009, Gilbert & Bankes 2002, Wilensky 1999).

## Fragestellung und Hypothese
Die einleitend dagestellte, grundlegende  Beobachtung, dass Trampelpfade entlang gemeinsam zurückgelegter Routen selbstorganisert entstehen wird durch die Neigung begründet, Wege zwischen einem _Hier_ und  _Dort_ zu optimieren. Es wird zudem beobachtet, dass weitere Akteure, sobald solche Spuren sichtbar sind, dazu neigen diese  zu nutzen, was wierderum die Sichtbarkeit der Trittspuren erhöht (vgl. Molnar 1997, Helbing 1997). Aus den den einzelnen Trittspuren werden dann Trampelpfade die scheinbar spezifischen Regeln folgen. Die konkrete Frage dieser Untersuchung lautet also: Entstehen Wege aus der Neigung der Nutzer bereits sichtbare Trittmuster zu nutzen und inwieweit ist es von der Wahrnehmung der Nutzer abhängig wie die Struktur der Wege ist?

Zur Untersuchung werden folgende Hypothesen aufgestellt:

1. Orientieren sich die Akteure an der Höhe der Popularität eines Trampelpfadpatches, dann (1) sind die Verbindungen zwischen Zielen kürzer, (2) es entstehen mehr direkte Punkt zu Punkt Wege und es entstehen weniger Trampelpfadpatches als bei der Orientierung an beliebigen Trampelpfadpatches. 

2. Je weitreichender die Wahrnehmung der Akteure ist, desto (1) stärker konvergieren Wege zu gemeinsam genutzten Pfaden mit (2) insgesamt mehr Nebenpfaden und (3) mehr Trampelpfadpatches als unter (1)

## Methoden
Zur Abstraktion und Modellbildung wird aus obiger Fragestellung folgendes **Wortmodell** aufgestellt (Bossel 2004):

    "Bei zufällig gegebenen festen Zielen in einem isomorphen Raum wird auf einer
     approximativ linearen (direkten) Verbindung zwischen diesen Zielen durch wiederholte
     Benutzung der gleichen Trittpatches ein Trampelpfad enstehen. Dieser direkte Weg
     wird modifiziert, falls die Neigung der Akteure bereits existierende Wegstücke auf
     dem Weg zum Ziel zu nutzen zunimmt. Je mehr dieser Wegstücke verfügbar sind und
     eingesehen werden können, desto stäker wird eine Veränderung der geraden Wege zu
     eher bogenförmig oder gekrümmten Wegen stattfinden."

### Rahmenbedingungen des Modelllaufs

Die Hypothesenüberprüfung soll mit Hilfe einer iterativen Veränderung der relevanten Parameter Sichtweite und Poularitätsgewichtung erfolgen. Hierfür ist grundsätzlich der Ansatz einer Sensitivitätsstudie geeignet (Thiele et al. 2014). Bei Anwendung einer systematischen Untersuchung werden reproduzierbare Raumbedingnen (siehe Abbildung 1) mit einer vollständigen Kombinationen verschiedener Akteurseinstellungen in definierter Anzahl wiederholt. Erwartet wird, dass zu den jeweiligen Paramterkombinationen spezifische und vegleichbare Raumstrukturen entstehen.

### Ziele und  Raum
Der Akteursraum wird durch die Positioniereung der Scheitelpunkte eines auf einer isomorphen Fläche (grün) leicht rotierten gleichseitigen Dreiecks (vgl. a. Helbing (1997)) gebildet (siehe Abbildung 1).

![Räumliche Positionen des Experiments Dreieck.](images/abb1.png)
Abbildung 1: Räumliche Positionen des Experiments. Die orangen Scheitelpunkte des  Dreiecks (rot eingekreist) sind die wechselseitig zugelosten Ziele. Grüne Flächen sind Grünland. Trittspuren und Agenten sind nicht gezeigt.

### Regeln aus dem Wortmodell
Aus dem obigen Wortmodell werden die folgenden Regeln abgeleitet:

#### Die Akteure (walkers) agieren nach den folgenden Regeln:

* haben immer ein bekanntes Ziel
* versuchen dieses Ziel auf direktem Weg zu erreichen
* identifizieren, je Schritt, ob eine Trittspur in Richtung zum Ziel erkennbar ist
* falls ja und so der Weg zum Ziel verkürzt wird, wählen sie die Richtung auf eine dieser Trittspuren 

#### Die Raumeinheiten (patches) haben die folgenden Eigenschaften:

* Nutzung (Grünland [grün], Trittspur [grau je nach popularity], Ziel [orange])

#### Folgende Interaktion (Prozesse) finden statt:

* Die Anziehungskraft (_popularity_) einer Trittspur wird bei jedem Betreten durch einen Akteur um einen Punkt aufgewertet. Ab einem definierten Schwellwert der _popularity_ wird aus Grünland eine sichtbare Trittspur.


### Das Netlogo Modell 
Das entwickelte NetLogo Modell  _"paths-simulater-2019"_  ist eine Weiterentwicklung des NetLogo-Library-Modells _"paths"_ (Grider & Wilensky 2015). Die dort implementierte Optimierungsfunktion zur Wegfindung (_best-way-to_) wurde um die Funktionalität nach maximaler Popularität zu selektieren erweitert. Der Algorithmus analysiert die Distanz zum Ziel und innerhalb eines definierten Sichtradius die Distanz zu einem Trittpach das den Weg zum Ziel verkürzt (falls vorhanden). Im Falle eines vorhandnen Trittpatchs wird dieses angesteuert. Für die vorliegende Untersuchung wurden darüberhinaus das in Abbildung 1 gezeigte Ziel-Szenario _Y_ in Anlehnung an Helbing (1997) Raumsetting implementiert und verwendet (vgl. Abbildung 1). 

Zur praktischen Umsetzung wird das Behaviour-Space-Werkzeug der NetLogo Programmierumgebung verwendet. Die in diese Modelldatei integrierten Behaviour-Space Skripte _"run_1_2_Y"_, _"run_3_4_Y"_ und _"run_5-7_Y"_ starten insgesamt 35 Modelläufe, die die Grundlage der Untersuchung darstellen. (vgl. Tabelle 1).

Die Simulationen werden je Szenario in 5-facher Wiederholung mit je zehn zufällig in der Modellwelt eingesetzten Akteuren durchgeführt. Die Akteure streben den ebenfalls jeweils zufällig zugelosten Zielpunkten zu. Bei Erreichen erfolgt eine Neulosung des nächsten Zieles. Für die genauen Einstellung je Simulation sei auf den Behaviour Space verwiesen.

Tabelle 1: Matrix der Modellaufparameter. Jeder Modellauf (run) wurde 5-fach wiederholt. Siehe auch Abbildungspanel 2, 3 und 4.

<table  style="width:90%">
    <tr>
        <td><b></td>
        <td><b>run_1</td>
        <td><b>run_2</td>
        <td><b>run_3 </td>
        <td><b>run_4</td>
        <td><b>run_5</td>
      <td><b>run_6</td>
        <td><b>run_7</td>
    </tr>
    <tr>
        <td><b>n-walkers</td>
         <td>10</td>
         <td>50</td>
         <td>10</td> 
        <td>10</td>
         <td>10</td>
        <td>10</td>
         <td>10</td>
    </tr>
    <tr>
        <td><b>walker-vis-dist</td>
         <td>1</td>
         <td>1</td>
         <td>25</td>
         <td>50</td>
         <td>1</td> 
         <td>25</td>
         <td>50</td>
    </tr>
    <tr>
        <td><b>max-pop</td>
         <td>false</td>
         <td>false</td>
         <td>false</td>
         <td>false</td> 
         <td>true</td>
         <td>true</td> 
         <td>true</td>
    </tr>
</table>




## Ergebnisse 
Die Simulationsläufe wurden über 2500 Zeitschritte iteriert und dann abgebrochen. In allen Modelläufen enstanden zu dieser Laufzeit keine neuen Wegstrukturen. 

Da in _run\_1 und _run\_2_ gut erkennbar ist, dass die grundsätzlichen Muster der patches mit einer _Popularity_ > _min-poplimit_  qualitativ übereinstimmend sind, werden exemplarisch die in Tabelle 1 gelisteten Läufe (runs) gezeigt. Dies vernachlässigt die Beobachtung, dass bei wenigen Akteuren und einer eingeschränkten Sicht (siehe _run\_3_) zwar qualitativ ähnliche und vergleichbare Muster enstehen, diese jedoch in der endgültigen Ausprägung und vor allem räumlichen Lage sehr varierend sind. Dieser räumliche Effekt ist der initialen Verteilung der Akteure geschuldet und es darf angenommen werden, dass bei einer gleichmässigen Verteilung im Raum die Muster auch für Läufe mit eingeschränkterer Wahrnehmung räumlich stabil bleiben.  

### Modelläufe 1 und 2 - Fokussierte Orientierung

In Abbildungspanel 2 sind _run\_1_ und _run\_2_ (vgl. Tabelle 1) dargestellt. Beide Läufe sind mit einer minimalen _walker-vis-dist_  mit dem Wert **1** durchgeführt worden. Gut zu erkennen sind die zwischen den Zielpunkten faktisch linearen und identischen Pfadmuster für Betretungshäufigkeiten größer des _min-poplimit_-Schwellenwertes. Auch gut zu erkennen ist die Verteilung der _popularity_, die einen massiven Peak im ersten Dezil aufweist und dann im 7 bis 9 Dezil einen leichten zweiten Peak produziert. Der erste Peak wird von den selten betretenen Patches erzeugt während der zweite Peak durch die Patches mit hohen (die Wege selber) aber nicht den höchsten (vor den Umkehrpunkten und "Eckentrittpatches" auf den Wegen) _popularity_-Werten der Patches gebildet wird. 

![Modellläufe 1 und 2]( images/abb2.png)

Abbildung 2: Modelllauf 1 und 2 mit : walker-vision-dist = 1, n-walkers = 10/50, max-pop = false, Wiederholungsläufe 1-5. Schwarze Patches sind _= min-poplimit_ häufig betreten worden. Größer _min-poplimit_ wird die Farbe Magenta bis weiss je nach Wertebereich von _maximum-popularity_ skaliert.

Die schwarz visualisierten Patches weisen eine Betretunghäufigkeit gleich des _min-poplimit_-Schwellenwertes aus. Sie markieren vor allem den Weg des walkers zum ersten Ziel. Es kann (eine Wiederholung >> 5 vorausgesetzt) erwartet werden, dass dieser Anteil im Verhältnis zu den patches mit einer _popularity_ größer des _min-poplimit_-Schwellenwertes sich über viele Simulationen stabilisiert und ähnlich ist. Allerdings ist auch hier die Abhängigkeit von der initialen räumlichen Verteilung der Akteure ersichtlich. Diese Ahnahme bestätigen eingeschränkt die Quotienten des Verhältnis von _popularity = min-poplimit_ **/** _popularity > min-poplimit_ 

Tabelle 2: Matrix der Quotienten von _popularity = min-poplimit_ **/** _popularity > min-poplimit_ (pop-ratio)


<table style="width:90%">
    <tr>
        <td><b></td>
        <td><b>run_1_1</td>
        <td><b>run_1_2</td>
        <td><b>run_1_3</td>
        <td><b>run_1_4</td>
        <td><b>run_1_5</td>
        <td><b>run_2_1</td>
        <td><b>run_2_2</td>
        <td><b>run_2_3</td>
        <td><b>run_2_4</td>
        <td><b>run_2_5</td>    </tr>
    <tr>
        <td><b>pop-ratio</td>
         <td>0.965</td>
         <td>0.796</td>
         <td>0.958</td> 
        <td>1.027</td>
         <td>1.033</td>
        <td>0.429</td>
         <td>0.450</td>
        <td>0.579</td>
         <td>0.600</td>
        <td>0.578</td>
    </tr>
</table>

### Modelläufe 3 und 4 - Flexible Orientierung 

In Abbildungspanel 3 sind _run\_3_ und _run\_4_ (vgl. Tabelle 1) dargestellt. Die Läufe unterscheiden sich durch die erweiterte Wahrnehmung der walker (siehe Tabelle 1). Gut zu erkennen sind die für Betretungshäufigkeiten größer des _min-poplimit_-Schwellenwertes zwischen den Zielpunkten deutlich gekrümmten und aufgespreizten Trampelpfade. Vor allem im _run\_3_ fällt die Variabilität des Hauptmusters auf. Hier ist die Reichweite der _walker-vis-dist_  mit 25 deutlich eingeschränkter als im _run\_4_ (50). Daher sind die resultierenden Muster abhängiger von der initialen Verteilung der Akteure. Im _run\_4_ ist dieses Muster dank der größeren Reichweite der _walker-vis-dist_ sichtbar stabiler und unabhängiger von der Erstverteilung der Akteure im Raum. Auch gut zu erkennen ist die Verteilung der _popularity_-Werte, die anders als zuvor in den ersten 3 Dezilen eine Häufung von Patches aufweist und dann quasi exponentiell abfällt. Die starke linksschiefe Verteilung wird durch das Aufspreizen der Wege und die hierdurch bedingte langsame Zunahme der Patches mit höherer Popularität erzeugt.

![Modellläufe 3 und 4]( images/abb3.png)

Abbildung 3: Modelllauf 3 und 4 für die Einstellungen siehe Tabelle 1. Schwarze Patches sind _gleich min-poplimit_ häufig betreten worden. _Größer min-poplimit_ wird die Farbe Magenta bis weiss je nach Wertebereich von _maximum-popularity_ skaliert.




### Modelläufe 5 - 7 - Fokussierte Orientierung auf maximale Popularität 

In Abbildungspanel 4 sind _run\_5 bis _run\_7 (vgl. Tabelle 1) dargestellt. Die Läufe unterscheiden sich durch die schrittweise erweiterte Wahrnehmung der walkers und ihrer Orientierung an Patches mit einer *maximalen* Popularität (siehe Tabelle 1). Die Läufe unterscheiden sich recht deutlich von den zuvor gezeigten Simulationen. Während _run\_5 erwartungsgemäß und bedingt durch die Bedingung _walker-vis-dist = 1_  als prinzipiell identisch mit _run\_1_ betrachtet werden kann, weichen die Läufe _run\_5_ und _run\_7_ erheblich von den vergleichbaren _walker-vis-dist_-Simulationen mit nicht optimierter Fokussierung auf maximale Popularität ab. Zunächst zeigen sich wie bei _run\_1_ und _run\_6_ als Hauptmuster eindeutig die linearen Optimierungspfade zwischen den Zielen die entsprechend hohe Popularitätswerte aufweisen. Betrachtet man aber vor allem den _run\_6_ zeigt sich, dass  wenig oder nur einmalig benutzte Parallel-Pfade zu den optimierten Hauptpfaden entstanden sind. Sehr stark tritt dies in _run\_6 #1-3_ und _run\_7 #2/#4_ hervor. 

![Modellläufe 5 - 7]( images/abb4.png)

Abbildung 4: Modelllauf 5 -7 für die Einstellungen siehe Tabelle 1. Schwarze Patches sind _= min-poplimit_ häufig betreten worden. Größer _min-poplimit_ wird die Farbe Magenta bis weiss je nach Wertebereich von _maximum-popularity_ skaliert.

## Diskussion

Betrachtet man die Ergebnisse vor dem Hintergrund der gestellten Hypothesen so können folgende Schlüsse gezogen werden: 

Hypothese 1 wurde mit den Modellläufen _run\_1, run\_5, run\_6, run\_7_ untersucht. In _run\_1_  und _run\_5 war die Wahrnehmung maximaler Popularität nicht eingestellt, allerdings wirkt die Wahrnehmungreichweite von **1** der walker, im Zusammenhang mit der zu jedem Zeitschritt aktiven Zielausrichtung, in vergleichbarer Weise. Die Läufe run\_6_ und _run\_7_  hingegen zeigen eindeutig lineare Optimierungsmuster, die bei mittlerer Wahrnehmungsreichweite deutlicher sichtbar werden als bei höherer Reichweite. Alle Varianten führen zu linearen und, falls für das Optimierungsverhalten notwendig, parallelen Wegstrukturen, die hinsichtlich der Entfernung optimiert kurz sind. Folglich kann Hypothese 1 sowohl hinsichtlich der Kürze der Wegstrecke als auch der Häufung von direkten Punkt-zu-Punkt Wegen bestätigt werden

Mit den Läufen _run\_3_ und _run\_4_ kann gezeigt werden, dass abhängig von der Anzahl der für die Akteure sichtbaren Trittpatches, gekrümmte und breitere Wege entstehen. Diese Wege sind nicht hinsichtlich ihrer Distanz zwischen den Zielpunkten optimiert. Ihre Lage im Raum ist offensichtlich von der zufälligen Erstverteilung der Akteure abhängig (_run\_3_) und wird mit zunehmender Wahrnehmungsreichweite bzw. Anzahl der Akteure stabiler reproduzierbar (_run\_4_). Aufgrund dieser Beobachtung kann auch Hypothese 2 bestätigt werden, da mit zunehmender Wahrnehmung die Trampelpfade stärker konvergieren und zu gemeinsam genutzten Pfaden, zusätzlichen Nebenpfaden und weiteren Pfadstrukturen ausgebaut werden.

Auf Grundlage dieser Beobachtungen kann geschlossen werden, dass das vorliegende Modell in der Lage ist, die, auch von anderen Autoren (vgl. Molnar 1997, Helbing 1997) beobachteten, Strukturen zuverlässig wiederzugeben und als Grundlage für weitere Fragestellungen wie etwa Barrieren oder komplexere Raumstrukturen geeignet erscheint.



## Referenzen 
1. Bossel, H, (2004), Systeme, Dynamik, Simulation : Modellbildung, Analyse und Simulation komplexer Systeme. Norderstedt, Books on Demand GmbH.
1. Feistel,R. & Ebeling, W. (1989), Evolution of Complex Systems. Self-Organization, Entropy and Development. Kluwer, Dordrecht,1989.
1. Gilbert N. & S. Bankes (2002), Platforms and methods for agent-based modeling. Proc. Natl. Acad.Sci. USA 99. Suppl 3.
1. Grider, R. and  U. Wilensky, U. (2015). NetLogo Paths model. (http://ccl.northwestern.edu/netlogo/models/Paths). Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
1. Helbing D., Keltsch & P. Molnar (1997), Modelling the evolution of human trail systems Nature  Vol. 388.
1. Henderson L.F. /1974), On the fluid mechanics of human crowd motion, Transportation Research, Volume 8, Issue 6, 1974, Pages 509-515  [DOI](https://doi.org/10.1016/0041-1647(74)90027-6).
1. <sup>*</sup> Machado A.: "Campos de Castilla", 1917, zit nach [URL](http://falschzitate.blogspot.com/2018/04/wege-entstehen-dadurch-dass-wir-sie.htm), Zugriff: 28.01.2020
1. Luhmann, N., (1984), Soziale Systeme: Grundriß einer allgemeinen Theorie, Frankfurt, Suhrkamp
1. Molnar P. (1995), Modellierung und Simulation der Dynamik von Fußgängerströmen (Diss.), [URL](http://www.cis.cau.edu/~pmolnar/dissertation/dissertation.html)
1. Schaber C. (2006), Space Syntax als Werkzeug zur Analyse des Stadtraums und menschlicher Fortbewegung im öffentlichen Raum unter besonderer Berücksichtigung schienengebundener Verkehrssysteme.   Das Beispiel des Leipziger City-Tunnels. Masterarbeit. [URL](https://e-pub.uni-weimar.de/opus4/frontdoor/deliver/index/docId/2112/file/SCHABER+2007+-+Space+Syntax+als+Werkzeug_pdfa.pdf), Zugriff: 28.01.2020
1. Schenk M. (1999), Optimierungsprinzipien der menschlichen Fortbewegung. [URL](https://books.google.de/books?id=lJzgxgEACAAJ)Zugriff: 28.01.2020
1. Teahan T. (2010a), Artificial Intelligence: Exercises – Agents and Environments, Ventus Publishing ApS, ISSBN 978-87-7681-591-2, [URL](https://library.ku.ac.ke/wp-content/downloads/2011/08/Bookboon/IT,Programming%20and%20Web/artificial-intelligence-exercises-i.pdf), Zugriff: 28.01.2020
1. Teahan T. (2010b), Artificial Intelligence: Exercises – Agent Behaviour I, Ventus Publishing ApS, ISBN 978-87-7681-592-9, [URL](https://library.ku.ac.ke/wp-content/downloads/2011/08/Bookboon/IT,Programming%20and%20Web/artificial-intelligence-exercises-ii.pdf), Zugriff: 28.01.2020
1. Thiele J. C., Kurtha W. & V. Grimm (2014), Facilitating Parameter Estimation and Sensitivity Analysis of Agent-Based Models: A Cookbook Using NetLogo and R, Journal of Artificial Societies and Social Simulation 17 (3) 11, [URL](http://jasss.soc.surrey.ac.uk/17/3/11.html), [DOI](DOI:10.18564/jasss.2503), Zugriff: 28.01.2020
1. Uhrmacher A. M. & D. Weyns (2009), Multi-Agent Systems: Simulation and Applications. (CRC Press, Inc., Boca Raton, FL, USA, 7.
1. Wilensky, U. (1999). NetLogo. (http://ccl.northwestern.edu/netlogo/), Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE
The above Text and the implementation of the current model is under Copyright of Rieke Ammoneit and Chris Reudenbach
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/3.0/de/"><img alt="Creative Commons Lizenzvertrag" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/3.0/de/88x31.png" /></a><br />Dieses Werk ist lizenziert unter einer <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/3.0/de/">Creative Commons Namensnennung - Nicht-kommerziell - Weitergabe unter gleichen Bedingungen 3.0 Deutschland Lizenz</a>.


All parts from Netlogo used library models have Copyright 2015 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person construction
false
0
Rectangle -7500403 true true 123 76 176 95
Polygon -1 true false 105 90 60 195 90 210 115 162 184 163 210 210 240 195 195 90
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Circle -7500403 true true 110 5 80
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -955883 true false 180 90 195 90 195 165 195 195 150 195 150 120 180 90
Polygon -955883 true false 120 90 105 90 105 165 105 195 150 195 150 120 120 90
Rectangle -16777216 true false 135 114 150 120
Rectangle -16777216 true false 135 144 150 150
Rectangle -16777216 true false 135 174 150 180
Polygon -955883 true false 105 42 111 16 128 2 149 0 178 6 190 18 192 28 220 29 216 34 201 39 167 35
Polygon -6459832 true false 54 253 54 238 219 73 227 78
Polygon -16777216 true false 15 285 15 255 30 225 45 225 75 255 75 270 45 285

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

person graduate
false
0
Circle -16777216 false false 39 183 20
Polygon -1 true false 50 203 85 213 118 227 119 207 89 204 52 185
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -8630108 true false 90 19 150 37 210 19 195 4 105 4
Polygon -8630108 true false 120 90 105 90 60 195 90 210 120 165 90 285 105 300 195 300 210 285 180 165 210 210 240 195 195 90
Polygon -1184463 true false 135 90 120 90 150 135 180 90 165 90 150 105
Line -2674135 false 195 90 150 135
Line -2674135 false 105 90 150 135
Polygon -1 true false 135 90 150 105 165 90
Circle -1 true false 104 205 20
Circle -1 true false 41 184 20
Circle -16777216 false false 106 206 18
Line -2674135 false 208 22 208 57

person lumberjack
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -2674135 true false 60 196 90 211 114 155 120 196 180 196 187 158 210 211 240 196 195 91 165 91 150 106 150 135 135 91 105 91
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -6459832 true false 174 90 181 90 180 195 165 195
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -6459832 true false 126 90 119 90 120 195 135 195
Rectangle -6459832 true false 45 180 255 195
Polygon -16777216 true false 255 165 255 195 240 225 255 240 285 240 300 225 285 195 285 165
Line -16777216 false 135 165 165 165
Line -16777216 false 135 135 165 135
Line -16777216 false 90 135 120 135
Line -16777216 false 105 120 120 120
Line -16777216 false 180 120 195 120
Line -16777216 false 180 135 210 135
Line -16777216 false 90 150 105 165
Line -16777216 false 225 165 210 180
Line -16777216 false 75 165 90 180
Line -16777216 false 210 150 195 165
Line -16777216 false 180 105 210 180
Line -16777216 false 120 105 90 180
Line -16777216 false 150 135 150 165
Polygon -2674135 true false 100 30 104 44 189 24 185 10 173 10 166 1 138 -1 111 3 109 28

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

person service
false
0
Polygon -7500403 true true 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -1 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -1 true false 123 90 149 141 177 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -16777216 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -11221820 true false 100 210 130 225 145 165 85 135 63 189
Polygon -2674135 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -13840069 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rabbit
false
0
Polygon -7500403 true true 61 150 76 180 91 195 103 214 91 240 76 255 61 270 76 270 106 255 132 209 151 210 181 210 211 240 196 255 181 255 166 247 151 255 166 270 211 270 241 255 240 210 270 225 285 165 256 135 226 105 166 90 91 105
Polygon -7500403 true true 75 164 94 104 70 82 45 89 19 104 4 149 19 164 37 162 59 153
Polygon -7500403 true true 64 98 96 87 138 26 130 15 97 36 54 86
Polygon -7500403 true true 49 89 57 47 78 4 89 20 70 88
Circle -16777216 true false 37 103 16
Line -16777216 false 44 150 104 150
Line -16777216 false 39 158 84 175
Line -16777216 false 29 159 57 195
Polygon -5825686 true false 0 150 15 165 15 150
Polygon -5825686 true false 76 90 97 47 130 32
Line -16777216 false 180 210 165 180
Line -16777216 false 165 180 180 165
Line -16777216 false 180 165 225 165
Line -16777216 false 180 210 210 240

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

squirrel
false
0
Polygon -7500403 true true 87 267 106 290 145 292 157 288 175 292 209 292 207 281 190 276 174 277 156 271 154 261 157 245 151 230 156 221 171 209 214 165 231 171 239 171 263 154 281 137 294 136 297 126 295 119 279 117 241 145 242 128 262 132 282 124 288 108 269 88 247 73 226 72 213 76 208 88 190 112 151 107 119 117 84 139 61 175 57 210 65 231 79 253 65 243 46 187 49 157 82 109 115 93 146 83 202 49 231 13 181 12 142 6 95 30 50 39 12 96 0 162 23 250 68 275
Polygon -16777216 true false 237 85 249 84 255 92 246 95
Line -16777216 false 221 82 213 93
Line -16777216 false 253 119 266 124
Line -16777216 false 278 110 278 116
Line -16777216 false 149 229 135 211
Line -16777216 false 134 211 115 207
Line -16777216 false 117 207 106 211
Line -16777216 false 91 268 131 290
Line -16777216 false 220 82 213 79
Line -16777216 false 286 126 294 128
Line -16777216 false 193 284 206 285

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

stud-pent
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 188 96 293 51 308 81 203 126
Circle -7500403 true true 117 27 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 120 90 135 195 105 285 120 300 150 300 165 225 180 300 210 300 225 285 195 195 210 90
Polygon -7500403 true true 122 94 77 199 107 214 152 109
Polygon -7500403 false true 60 150
Polygon -1184463 false false 60 45 0 120 0 225 120 225 120 120 60 45
Polygon -2674135 true false 115 65 196 44 162 -4 148 18 130 4
Polygon -2674135 true false 168 119 195 90 270 60 285 94 212 124 240 255 180 270 150 270 105 255 90 255 135 165 135 165 113 196 85 179 120 90
Polygon -1184463 false false 67 46 7 121 7 226 127 226 127 121 67 46
Polygon -1184463 false false 60 45 0 120 0 225 120 225 120 120 60 45

stud-square
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 false true 60 150
Polygon -1184463 false false 285 105 285 210 180 210 180 105
Rectangle -1184463 false false 184 109 281 209

stud_tri
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 false true 60 150
Polygon -1184463 false false 0 180 75 90 150 210 0 180
Polygon -1184463 false false 8 178 75 97 144 208

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

tree pine
false
0
Rectangle -6459832 true false 120 225 180 300
Polygon -7500403 true true 150 240 240 270 150 135 60 270
Polygon -7500403 true true 150 75 75 210 150 195 225 210
Polygon -7500403 true true 150 7 90 157 150 142 210 157 150 7

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="run_all_max_2" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results/results " behaviorspace-experiment-name behaviorspace-run-number ".csv")
export-plot "number of patches per percentile"  (word "results/results " behaviorspace-experiment-name behaviorspace-run-number "_number-of-patches-per-percentile.csv")</final>
    <timeLimit steps="2500"/>
    <exitCondition>stopitnow</exitCondition>
    <metric>count-of-trampling</metric>
    <metric>count-of-trampling-without-popularity</metric>
    <metric>count-of-popularity-minimum</metric>
    <metric>popularity-maximum</metric>
    <metric>popularity-average</metric>
    <enumeratedValueSet variable="show-goal">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-v-angle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-width">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-vision-dist">
      <value value="1"/>
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pop">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-lowlimit">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_color">
      <value value="&quot;red&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="road-width">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roads-pop">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preset-roads">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-vision">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selected-experiment">
      <value value="&quot;Y&quot;"/>
      <value value="&quot;square&quot;"/>
      <value value="&quot;houseOfSantaClaus&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-walker">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="message">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="run_3_4_y" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results/results " behaviorspace-experiment-name behaviorspace-run-number ".csv")
export-plot "number of patches per percentile"  (word "results/results " behaviorspace-experiment-name behaviorspace-run-number "_number-of-patches-per-percentile.csv")</final>
    <timeLimit steps="2500"/>
    <exitCondition>stopitnow</exitCondition>
    <metric>count-of-trampling</metric>
    <metric>count-of-trampling-without-popularity</metric>
    <metric>count-of-popularity-minimum</metric>
    <metric>popularity-maximum</metric>
    <metric>popularity-average</metric>
    <enumeratedValueSet variable="show-goal">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-v-angle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-width">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-vision-dist">
      <value value="25"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-lowlimit">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_color">
      <value value="&quot;red&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="road-width">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roads-pop">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preset-roads">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-vision">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selected-experiment">
      <value value="&quot;Y&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-walker">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="message">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="run_1_3_4_square" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results/results " behaviorspace-experiment-name behaviorspace-run-number ".csv")
export-plot "number of patches per percentile"  (word "results/results " behaviorspace-experiment-name behaviorspace-run-number "_number-of-patches-per-percentile.csv")</final>
    <timeLimit steps="2500"/>
    <exitCondition>stopitnow</exitCondition>
    <metric>count-of-trampling</metric>
    <metric>count-of-trampling-without-popularity</metric>
    <metric>count-of-popularity-minimum</metric>
    <metric>popularity-maximum</metric>
    <metric>popularity-average</metric>
    <enumeratedValueSet variable="show-goal">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-v-angle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-width">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-vision-dist">
      <value value="1"/>
      <value value="25"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-lowlimit">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_color">
      <value value="&quot;red&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="road-width">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roads-pop">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preset-roads">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-vision">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selected-experiment">
      <value value="&quot;square&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-walker">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="message">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="run_4-7_y" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results/results " behaviorspace-experiment-name behaviorspace-run-number ".csv")
export-plot "number of patches per percentile"  (word "results/results " behaviorspace-experiment-name behaviorspace-run-number "_number-of-patches-per-percentile.csv")</final>
    <timeLimit steps="2500"/>
    <exitCondition>stopitnow</exitCondition>
    <metric>count-of-trampling</metric>
    <metric>count-of-trampling-without-popularity</metric>
    <metric>count-of-popularity-minimum</metric>
    <metric>popularity-maximum</metric>
    <metric>popularity-average</metric>
    <enumeratedValueSet variable="show-goal">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-v-angle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-width">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="walker-vision-dist">
      <value value="1"/>
      <value value="25"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-pop">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pop-lowlimit">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-pop">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p_color">
      <value value="&quot;red&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="road-width">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="roads-pop">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preset-roads">
      <value value="&quot;none&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vis-vision">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="selected-experiment">
      <value value="&quot;Y&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-walker">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="message">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
