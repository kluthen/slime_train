# Precursor

Slime train is an almost idle game for mobile (android to begin with) that should be accessible to kids (3 to 5 yo). 
It must come with screen lock and timer feature (ensuring a running session is locked: can't quit without a complex operation to do(a la disney+), can play for too long(no more than 15 min)).

# Inspiration

LocoRoco Cocoreccho! is the main inspiration. 
We will use slimes instead of the blurbs of locoroco.

# Gameplay

Slimes either sleep or follow the "path" which most certainly loops.

We will limit the controls to orienting the phone screen (variation of +/- 45°) to help the the slimes reach certains locations. 

touching the screen will attract attention (and order nearby slimes) to move toward that direction. 

Only a few actions are available to begin with: 

* Activating gates (sort of flow redirection): mostly will be used to pool slimes into a waiting basket to trigger opening toward the next section.
* jump: when clicking on something out of reach (no ground pathway toward it) the slime will attempt jumping (horizontally or vertically)
* activating objects: some objects will only activate when slimes touch thems 
* revealing zones: some spaces will only be revealed when slimes approach them.
* fusing: two slimes of the same types can fuse into a bigger slime of the same type.
* defusing: some location may instantly explode slimes into their base format. 
* waking: when a slime touch a sleeping one, it wakes.

# Futur gameplay:

Expected in the future is slime fusion v2: slimes of different types merging when the right conditions are met: creating new types of slimes.
These new slimes will have opportunity to have their own unique interactions with the environment: 

Fire slime may burn through grass, ice slime may freeze water, etc...

# DA

We keep something very simple and curved, high constrat and low details. We may introduce at a later step theming ( desert, forest, rivers, etc: which would provide slight decorative features or color palette change, and maybe puzzle selection, but nothing more drastic). 

# Music

We have a music generator under production currently we may include it in this game. I do understand that music is also what made Locoroco cocoreccho a hit. 

# Objectives

## Level editor

many questions here how to design level: i suspect that part of it is clearly static vectorial shapes. with Z index. 
objects (still vectorial) with motions applied to them (like spinning, flowing, etc) that can be "pasted" on the scene, but are unconsequential to the game.
Object (this time solid to the player) need to be designed and effect depending on the slimes present (number, type, etc) 

I don't know how to design such items, nor how should we work on this.

Depending on how we go at it, we may or may not need to have our own level editor, may be we could reuse some other ?

Expected is that the android app will begin with a first level fully designed, and later we may ship other (as paid DLC).

## Android game app 

# Technical constraints

I don't want to use unreal or unity. We mostly need a lightweight 2D physic. and a vectorial renderer.

While the main (intended) output is android (and later maybe ios) app. We may expect to have either a web or debian app to render and iterate quicker ?

