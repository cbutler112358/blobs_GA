globals [
  max-food ;; set during setup
  K ;; carrying capacity of environment
]

breed [ blobs blob ]
breed [ foods food ]

patches-own [
  has-food?
]

blobs-own [

  max-energy
  num-size
  fang-size
  current-energy

  ;; how far am I allowed to step?
  max-speed

  chaseTime
  chaseStep

  ;; looking for food
  forageTurn
  forageStep

  ;; looking for prey
  huntingTurn
  huntingStep

  ;; amble
  ambleTurn
  ambleStep

  fleeStep

  ;; when do I begin foraging? Above which I will hunt
  hungryThresh

  ;; can I breed?
  has-breed

  ;; do not eat above this level!
  ;; full ;; max 50
  ;; a blob is full when it's energy is maxed
]


to setup
  clear-all
  set K 1000
  setup-food
  setup-agents
  reset-ticks
end


to go
  ;; check my energy first
  if count blobs = 0 [ stop ]
  ask blobs [
    if current-energy <= 0 [ die ]
    set label round current-energy
  ]
  decide ;; includes move
  if (ticks mod grow-time) = 0 [ grow-food ]
  decay

  ;; let breed? count blobs with [current-energy > max-energy]
  ;; if breed? > 0 [
  ;;  while [(count blobs) < num-blobs][ breed-agent ]
  ;; ]
  ;; histogram [fang-size] of blobs
  tick
end

to step
  ;; check my energy first
  if count blobs = 0 [ stop ]
  ask blobs [
    if current-energy <= 0 [ die ]
    set label round current-energy
  ]
  decide ;; includes move
  if (ticks mod grow-time) = 0 [ grow-food ]
  decay
  ;; let breed? count blobs with [current-energy > max-energy]
  ;; if breed? > 0 [
  ;;   while [(count blobs) < num-blobs][ breed-agent ]
  ;; ]
  ;; histogram [fang-size] of blobs
end

to setup-agents
  create-blobs num-blobs
  [
    set shape "circle"
    ;; choose random values
    setxy random-pxcor random-pycor

    set has-breed 0

    ;; size
    let %energy random max-life + 1
    set max-energy %energy
    set current-energy %energy

    ;; step size
    ifelse %energy < (0.2 * max-life)
    [ ;; extra small
      set max-speed 0.5 * max-speed-tot
      set size 5
      set color 125
      set num-size 1
    ]
    [
      ifelse %energy < (0.4 * max-life)
      [ ;; small
        set max-speed 0.4 * max-speed-tot
        set size 6
        set color 105
        set num-size 2
      ]
      [
        ifelse %energy < (0.6 * max-life)
        [ ;; medium
          set max-speed 0.3 * max-speed-tot
          set size 7
          set color 65
          set num-size 3
        ]
        [
          ifelse %energy < (0.8 * max-life)
          [ ;; large
            set max-speed 0.2 * max-speed-tot
            set size 8
            set color 25
            set num-size 4
          ]
          [
            ;; extra large
            set max-speed 0.1 * max-speed-tot
            set size 9
            set color 15
            set num-size 5
          ]
        ]
      ]
    ]

    ;; fang size
    set fang-size random 7

    ;; chase time
    set chaseTime random 10 + 1
    ;; chase step
    set chaseStep ((random-float 1) * max-speed)


    ;; forage turn
    set forageTurn random 365
    ;; forage step
    set forageStep ((random-float 1) * max-speed)

    ;; hunting turn
    set huntingTurn random 365
    ;; hunting step
    set huntingStep ((random-float 1) * max-speed)

    ;; amble turn
    set ambleTurn random 365
    ;; amble step
    set ambleStep ((random-float 1) * max-speed)

    ;; flee step
    set fleeStep ((random-float 1) * max-speed)

    ;; threshold I begin to forage
    set hungryThresh random %energy + 1



  ] ;; end of create-blobs
end


to setup-food
  ;; make the environment bigger
  let worldDim 200 ;; length-of-patch ;; - 1
  resize-world 0 worldDim 0 worldDim
  set-patch-size 400 / worldDim


  ;; ask each patch if they want to grow food..
  ask patches [
    let %food random-float 1
    ifelse (%food < food-prob)
    [
      sprout-foods 1 [
        set color one-of base-colors
        set shape "square"
        set size 2.5
      ]
      set has-food? 1
    ]
    [
      set has-food? 0
    ]
  ]

  set max-food count foods

end

to decide
  let numBlobs count blobs
  ask blobs [

    ifelse current-energy > max-energy
    [
      look-breed
    ]
    [
      ifelse current-energy > hungryThresh
      [
        ;; on the hunt for prey...

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; fangs required for hunting???
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
         ;; ifelse (fang-size > 0) [
          look-hunt
         ;; ][
         ;;   look-forage
         ;; ]
      ]
      [
        ;; time to forage for food..
        look-forage
      ]
    ] ;; end of ifelse > max-energy


  ]
end


to look-amble
  ;; look to blobs around you, if there are any with greater size than
  ;; run!
  let pred? 0
  if (count (other (blobs in-radius look-radius))) > 0
  [
    set pred? max [fang-size] of other blobs in-radius look-radius
  ]

  ifelse num-size < pred?
  [
    ;; there's a predator, run!
    flee
  ]
  [
    ;; there's no predator around, time to chill
    rt random-normal ambleTurn 1
    ;; step forward
    let stepFd random-normal ambleStep 1
    if (stepFd < 0) [ set stepFd 0 ]
    if (stepFd > max-speed) [
      set stepFd max-speed
    ]

    fd stepFd
    set current-energy (current-energy - movement-cost * stepFd)
  ]

end

to look-hunt
  ;; look to blobs around you, if there are any with greater size than you,
  ;; run!
  let pred? 0
  if (count (other (blobs in-radius look-radius))) > 0
  [
    set pred? max [fang-size] of other blobs in-radius look-radius
  ]

  ;; show pred?

  let mySize fang-size ;; (storing my size for later)
  let myChaseStep chaseStep ;; (storing hunting step for later)
  ifelse num-size < pred?
  [
    ;; there's a predator, run!
    flee
  ]
  [
    ;; there's no predator around, any food?
    let numBitePrey count other (blobs with [num-size < mySize] in-radius bite-radius)
    ifelse numBitePrey > 0
    [ ;; there's some prey, take a bite!
      let newPrey one-of other (blobs with [num-size < mySize] in-radius bite-radius)
      set current-energy (current-energy + biomass-conv * ([current-energy] of newPrey))
      ask newPrey
      [
        die
      ]
    ]
    [
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; in past version, forgot to include "and (num-size < mySize)" -- blobs evolved killing
      ;; even when conversion was zero because the code killed prey thinking they could be
      ;; eaten
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; no one in bite radius, but can I lunge to get them?
      let numLungePrey count other (blobs with [((fleeStep + distance myself) < myChaseStep) and (num-size < mySize)] in-radius look-radius)
      ifelse numLungePrey > 0
      [
        ;; yes! I can eat them
        let nearestLungePrey one-of other (blobs with [((fleeStep + distance myself) < myChaseStep) and (num-size < mySize)] in-radius look-radius)
        set current-energy (current-energy + biomass-conv * ([current-energy] of nearestLungePrey))

        let stepFd distance nearestLungePrey
        let faceXCoord [xcor] of nearestLungePrey
        let faceYCoord [ycor] of nearestLungePrey
        facexy faceXCoord faceYCoord
        fd stepFd

        set current-energy (current-energy - movement-cost * stepFd)

        ask nearestLungePrey [ die ]

      ]
      [
        ;; no one to lunge and eat, anyone to hunt?
        ;; no one to bite and no predator... anyone to hunt?
        let numPrey count other (blobs with [num-size < mySize] in-radius look-radius)
        ifelse numPrey > 0
        [
          ;; there's prey! hunt it!
          let nearestNeighborPrey (other blobs with [num-size < mySize]) with-min [distance myself]
          let meanXCoord mean ([xcor] of nearestNeighborPrey)
          let meanYCoord mean ([ycor] of nearestNeighborPrey)
          facexy meanXCoord meanYCoord
          ;; step forward
          let stepFd random-normal chaseStep 1
          if (stepFd < 0) [ set stepFd 0 ]
          if (stepFd > max-speed) [
            set stepFd max-speed
          ]

          fd stepFd
          set current-energy (current-energy - movement-cost * stepFd)


        ]
        [
          ;; no prey, just look around
          rt random-normal huntingTurn 1
          ;; step forward
          let stepFd random-normal huntingStep 1
          if (stepFd < 0) [ set stepFd 0 ]
          if (stepFd > max-speed) [
            set stepFd max-speed
          ]

          fd stepFd
          set current-energy (current-energy - movement-cost * stepFd)
        ] ;; end of ifelse prey

      ] ;; end of ifelse lunge
    ]

  ] ;; end of ifelse looking for predator



end


to look-forage
  ;; look to blobs around you, if there are any with greater size than you,
  ;; run!
  let pred? 0
  if count (other blobs in-radius look-radius) > 0
  [
    set pred? max [fang-size] of other (blobs in-radius look-radius)
  ]
  let mySize fang-size ;; (storing my size for later)
  ifelse num-size < pred?
  [
    ;; there's a predator, run!
    flee
  ]
  [
    ;; there's no predator around, any food?
    let numBitePrey count foods in-radius bite-radius
    ifelse numBitePrey > 0
    [ ;; there's some food, take a bite!
      ask one-of foods in-radius bite-radius
      [
        die
      ]

      ;; yummy!
      set current-energy (current-energy + food-energy)
    ]
    [
      ;; no one to bite and no predator... anyone to hunt?
      let numPrey count foods in-radius look-radius
      ifelse numPrey > 0
      [
        ;; there's food -- go eat it!
        let nearestNeighborPrey one-of foods with-min [distance myself]
        let stepFd distance nearestNeighborPrey
        ifelse ((distance nearestNeighborPrey ) <= forageStep)
        [

          let faceXCoord [xcor] of nearestNeighborPrey
          let faceYCoord [ycor] of nearestNeighborPrey
          facexy faceXCoord faceYCoord
          fd stepFd

          set current-energy (current-energy - movement-cost * stepFd + food-energy)
          ask foods in-radius 0 [ die ]
        ]
        [
          ;; it's not close enough..
          set nearestNeighborPrey foods with-min [distance myself]
          let meanXCoord mean ([xcor] of nearestNeighborPrey)
          let meanYCoord mean ([ycor] of nearestNeighborPrey)
          facexy meanXCoord meanYCoord

          ;; step forward
          set stepFd random-normal forageStep 1
          if (stepFd < 0) [ set stepFd 0 ]
          if (stepFd > max-speed) [
            set stepFd max-speed
          ]

          fd stepFd
          set current-energy (current-energy - movement-cost * stepFd)

        ]


      ] ;; end of if numPrey > 0 statement
      [
        ;; no food, just look around
        rt random-normal forageTurn 1
        ;; step forward
        let stepFd random-normal forageStep 1
        if (stepFd < 0) [ set stepFd 0 ]
        if (stepFd > max-speed) [
          set stepFd max-speed
        ]

        fd stepFd
        set current-energy (current-energy - movement-cost * stepFd)
      ] ;; end of ifelse prey
    ]

  ] ;; end of ifelse looking for predator



end



to flee
  ;; run from the closest predator!
  let mySize num-size
  let nearestNeighborPred (other blobs with [fang-size > mySize]) with-min [distance myself]
  let meanXCoord mean ([xcor] of nearestNeighborPred)
  let meanYCoord mean ([ycor] of nearestNeighborPred)
  facexy meanXCoord meanYCoord
  rt 180

  let stepFd random-normal fleeStep 1
  if (stepFd < 0) [ set stepFd 0 ]
  if (stepFd > max-speed) [
    set stepFd max-speed
  ]

  fd stepFd
  set current-energy (current-energy - movement-cost * stepFd)
end

to grow-food
  ;; is there a food shortage?
  let foodCount count foods
  while [foodCount < max-food] [
    ;; grow food
    ask one-of patches with [has-food? = 0] [
      let %food-prob random-float 1
      if %food-prob < food-prob [
        sprout-foods 1 [
          set color one-of base-colors
          set shape "square"
          set size 2.5
        ]
      ]
    ] ;; end of ask one patch

    set foodCount count foods
  ] ;; end of while loop

end

to breed-agent
let parents blobs with [current-energy > max-energy]

;; create a new turtle with average qualities..
create-blobs 1 [
  set shape "circle"
  ;; choose random values
  setxy random-pxcor random-pycor

  let %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set max-energy random max-life + 1
  ]
  [
    set max-energy one-of ([max-energy] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set fang-size random 7
  ]
  [
    set fang-size one-of ([fang-size] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set chaseTime random 10 + 1
  ]
  [
    set chaseTime one-of ([chaseTime] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set chaseStep ((random-float 1) * max-speed)
  ]
  [
    set chaseStep one-of ([chaseStep] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set forageTurn random 365
  ]
  [
    set forageTurn one-of ([forageTurn] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set forageStep ((random-float 1) * max-speed)
  ]
  [
    set forageStep one-of ([forageStep] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set forageStep ((random-float 1) * max-speed)
  ]
  [
    set forageStep one-of ([forageStep] of parents)
  ]


  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set huntingTurn random 365
  ]
  [
    set huntingTurn one-of ([huntingTurn] of parents)
  ]


  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set huntingStep ((random-float 1) * max-speed)
  ]
  [
    set huntingStep one-of ([huntingStep] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set ambleTurn random 365
  ]
  [
    set ambleTurn one-of ([ambleTurn] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set ambleStep ((random-float 1) * max-speed)
  ]
  [
    set ambleStep one-of ([ambleStep] of parents)
  ]


  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set fleeStep ((random-float 1) * max-speed)
  ]
  [
    set fleeStep one-of ([fleeStep] of parents)
  ]

  set %mutation (random-float 1)
  ifelse %mutation < mutation-prob
  [
    set hungryThresh random max-energy + 1
  ]
  [
    set hungryThresh mean ([hungryThresh] of parents)
  ]

  set current-energy max-energy


  ifelse max-energy < (0.2 * max-life)
  [ ;; extra small
    set max-speed 0.5 * max-speed-tot
    set size 5
    set color 125
    set num-size 1
  ]
  [
    ifelse max-energy < (0.4 * max-life)
    [ ;; small
      set max-speed 0.4 * max-speed-tot
      set size 6
      set color 105
      set num-size 2
    ]
    [
      ifelse max-energy < (0.6 * max-life)
      [ ;; medium
        set max-speed 0.3 * max-speed-tot
        set size 7
        set color 65
        set num-size 3
      ]
      [
        ifelse max-energy < (0.8 * max-life)
        [ ;; large
          set max-speed 0.2 * max-speed-tot
          set size 8
          set color 25
          set num-size 4
        ]
        [
          ;; extra large
          set max-speed 0.1 * max-speed-tot
          set size 9
          set color 15
          set num-size 5
        ]
      ]
    ]
  ]

]

end


to look-breed
  ;; look to blobs around you, if there are any with greater size than you,
  ;; run!
  let pred? 0
  if count (other blobs in-radius look-radius) > 0
  [
    set pred? max [fang-size] of other (blobs in-radius look-radius)
  ]

  ifelse num-size < pred?
  [
    ;; there's a predator, run!
    flee
  ]
  [
    let numMates count (other blobs with [max-energy > current-energy] in-radius breed-radius)
    ifelse numMates > 0
    [
      ;; breed
      let mate one-of (other blobs with [max-energy > current-energy] in-radius breed-radius)
      let me (blobs with [max-energy > current-energy] in-radius 0)

      let parents (turtle-set self mate)
      ;; let parents (mate) (myself)

      ;; create a new turtle with average qualities..
      let numBlobs count blobs
      let numOffspring round (num-offspring * (1 - (numBlobs / K)))
      let ughOffspring max (list 0 numOffspring)
      hatch-blobs ughOffspring [
        set shape "circle"
        ;; choose random values
        setxy random-pxcor random-pycor

        let %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set max-energy random max-life + 1
        ]
        [
          set max-energy one-of ([max-energy] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set fang-size random 7
        ]
        [
          set fang-size one-of ([fang-size] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set chaseTime random 10 + 1
        ]
        [
          set chaseTime one-of ([chaseTime] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set chaseStep ((random-float 1) * max-speed)
        ]
        [
          set chaseStep one-of ([chaseStep] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set forageTurn random 365
        ]
        [
          set forageTurn one-of ([forageTurn] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set forageStep ((random-float 1) * max-speed)
        ]
        [
          set forageStep one-of ([forageStep] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set forageStep ((random-float 1) * max-speed)
        ]
        [
          set forageStep one-of ([forageStep] of parents)
        ]


        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set huntingTurn random 365
        ]
        [
          set huntingTurn one-of ([huntingTurn] of parents)
        ]


        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set huntingStep ((random-float 1) * max-speed)
        ]
        [
          set huntingStep one-of ([huntingStep] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set ambleTurn random 365
        ]
        [
          set ambleTurn one-of ([ambleTurn] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set ambleStep ((random-float 1) * max-speed)
        ]
        [
          set ambleStep one-of ([ambleStep] of parents)
        ]


        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set fleeStep ((random-float 1) * max-speed)
        ]
        [
          set fleeStep one-of ([fleeStep] of parents)
        ]

        set %mutation (random-float 1)
        ifelse %mutation < mutation-prob
        [
          set hungryThresh random max-energy + 1
        ]
        [
          set hungryThresh mean ([hungryThresh] of parents)
        ]

        set current-energy max-energy


        ifelse max-energy < (0.2 * max-life)
        [ ;; extra small
          set max-speed 0.5 * max-speed-tot
          set size 5
          set color 125
          set num-size 1
        ]
        [
          ifelse max-energy < (0.4 * max-life)
          [ ;; small
            set max-speed 0.4 * max-speed-tot
            set size 6
            set color 105
            set num-size 2
          ]
          [
            ifelse max-energy < (0.6 * max-life)
            [ ;; medium
              set max-speed 0.3 * max-speed-tot
              set size 7
              set color 65
              set num-size 3
            ]
            [
              ifelse max-energy < (0.8 * max-life)
              [ ;; large
                set max-speed 0.2 * max-speed-tot
                set size 8
                set color 25
                set num-size 4
              ]
              [
                ;; extra large
                set max-speed 0.1 * max-speed-tot
                set size 9
                set color 15
                set num-size 5
              ]
            ]
          ]
        ]

      ] ;; end of create-blobs



      set has-breed 1
      ;; kill the parent
      die
      ;; set current-energy (round (current-energy / 2))
      ask mate
      [
        ;; set has-breed 1
        ;; set current-energy (round (current-energy / 2))
        die
      ]


    ]
    [
      ;; there's no predator/mate around, time to chill
      rt random-normal ambleTurn 1
      ;; step forward
      let stepFd random-normal ambleStep 1
      if (stepFd < 0) [ set stepFd 0 ]
      if (stepFd > max-speed) [
        set stepFd max-speed
      ]

      fd stepFd
      set current-energy (current-energy - movement-cost * stepFd)
    ]

  ]

end

to decay
  ;; organism and fang size cost energy...
  ask blobs
  [
    set current-energy (current-energy - (fang-cost * fang-size))
    set current-energy (current-energy - (size-cost * num-size))
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
225
10
633
419
-1
-1
2.0
1
10
1
1
1
0
1
1
1
0
200
0
200
0
0
1
ticks
30.0

SLIDER
10
11
182
44
num-blobs
num-blobs
0
500
400.0
10
1
NIL
HORIZONTAL

SLIDER
12
58
184
91
food-prob
food-prob
0
0.1
0.04
0.01
1
NIL
HORIZONTAL

BUTTON
13
109
76
142
NIL
setup
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
81
109
144
142
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
147
109
210
142
NIL
step
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
13
156
185
189
look-radius
look-radius
0
5
3.0
0.5
1
NIL
HORIZONTAL

SLIDER
13
198
185
231
bite-radius
bite-radius
0
0.5
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
14
240
186
273
food-energy
food-energy
0
20
15.0
1
1
NIL
HORIZONTAL

SLIDER
14
287
186
320
max-life
max-life
0
300
200.0
10
1
NIL
HORIZONTAL

SLIDER
14
331
186
364
mutation-prob
mutation-prob
0
0.2
0.1
0.01
1
NIL
HORIZONTAL

PLOT
646
11
932
202
Agent pops
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"XS" 1.0 0 -5825686 true "" "plot count blobs with [num-size = 1]"
"S" 1.0 0 -13345367 true "" "plot count blobs with [num-size = 2]"
"M" 1.0 0 -13840069 true "" "plot count blobs with [num-size = 3]"
"L" 1.0 0 -955883 true "" "plot count blobs with [num-size = 4]"
"XL" 1.0 0 -2674135 true "" "plot count blobs with [num-size = 5]"

SLIDER
14
375
186
408
fang-cost
fang-cost
0
10
0.0
0.5
1
NIL
HORIZONTAL

SLIDER
15
414
187
447
size-cost
size-cost
0
2
1.0
0.05
1
NIL
HORIZONTAL

SLIDER
15
455
187
488
max-speed-tot
max-speed-tot
0
10
10.0
0.5
1
NIL
HORIZONTAL

PLOT
648
210
848
360
fang-size
NIL
NIL
0.0
6.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [fang-size] of blobs"

MONITOR
412
466
498
511
mean energy
mean [current-energy] of blobs
1
1
11

SLIDER
16
497
188
530
movement-cost
movement-cost
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
225
427
397
460
biomass-conv
biomass-conv
0
3
2.48
0.01
1
NIL
HORIZONTAL

SLIDER
226
465
398
498
num-offspring
num-offspring
1
6
3.0
1
1
NIL
HORIZONTAL

SLIDER
227
503
399
536
grow-time
grow-time
1
10
3.0
1
1
NIL
HORIZONTAL

MONITOR
508
467
565
512
pop.
count blobs
17
1
11

SLIDER
411
426
583
459
breed-radius
breed-radius
0
10
4.0
1
1
NIL
HORIZONTAL

PLOT
648
371
848
521
hunting-step
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [huntingStep] of blobs"

PLOT
1144
20
1344
170
chase-step
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [chaseStep] of blobs"

PLOT
857
371
1057
521
max-speed
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [max-speed] of blobs"

PLOT
1064
372
1264
522
hungry-thresh
NIL
NIL
0.0
300.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [hungryThresh] of blobs"

PLOT
1063
211
1263
361
max-energy
NIL
NIL
0.0
300.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [max-energy] of blobs"

PLOT
938
21
1138
171
flee-step
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [fleeStep] of blobs"

MONITOR
572
469
641
514
fang-size=1
count blobs with [num-size = 1]
17
1
11

PLOT
858
210
1058
360
forage-step
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [forageStep] of blobs"

@#$#@#$#@

# Ideas and updates

## 07/30/2021

Blobs grew fangs to "hunt" because the landscape navigation strategy of hunting was more 
rewarding than the landscape navigation strategy involved with foraging. Perhaps agents
posess probabilities dictating how often they hunt and how often they forage. Perhaps
blobs could also evolve look-radii so that the foraging and hunting algorithms can change
with the population? 

# Other stuff 

## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

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
0
@#$#@#$#@
