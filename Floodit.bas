' Floodit Game
' Rev 1.0.0 William M Leue 23-Mar-2022

option base 1
option default integer

const NSIZES = 6
const MINCOLORS = 3
const MAXCOLORS = 8
const NCOLORS = 6
const TOP_MARGIN = 40

const PC_Y    = 450
const PC_W    = 40
const PC_H    = 40
const PC_SPAC = 20

const SCORE_X = 625
const SCORE_Y = 100
const SCORE_W = 190
const SCORE_H = 100

const ESC = 27
const UP = 128
const DOWN = 129
const LEFT = 130
const RIGHT = 131
const ENTER = 13

const MCHAN = 2

dim sizes(NSIZES) = (6, 10, 14, 18, 22, 26)
dim csizes(NSIZES)
dim maxMoves(NCOLORS, NSIZES)
dim colors(MAXCOLORS)

' major game parameters
dim theSizeIndex = 0
dim theNumColorIndex = 0
dim theNumColors = 0
dim theCol = 0
dim theRow = 0
dim theBoardX = 0
dim theBoardY = 0
dim theBoardWidth = 0
dim theBoardHeight = 0
dim theCellSize = 0
dim theBoardSize = 0
dim theBoard(2, 2)  ' will be redimensioned
dim theFillColor = 0
dim theMaxMoves = 0
dim num_games = 0
dim num_user_moves = 0
dim is_won = 0
dim is_filled = 0
dim is_running = 0
dim cumulative_score = 0

' mouse state machine parameters
dim hasMouse = 0
dim left_click = 0
dim left_busy = 0
dim theMouseX = 0
dim theMouseY = 0

' Main program
open "debug.txt" for output as #1
InitCursor
InitMouse
ReadNumMoves
ReadCellSizes
ReadColors
ShowStartScreen
left_click = 0
left_busy = 0
do
  ChooseParams
  InitGame
  DrawBoard
  if hasMouse then
    GetUserInputs
  else
    PlayLoop theNumColors
  end if
loop
end

' Initialize the cursor
sub InitCursor
  gui cursor on 1
end sub

' Initialize Mouse if one is present
sub InitMouse
  on error skip 1
  controller mouse open MCHAN, LClick
  if mm.errno <> 0 then
    hasMouse = 0
    exit sub
  else
    hasMouse = 1
    gui cursor show
    settick 20, UpdateCursor
  end if
end sub

' If mouse is used, make the cursor track the mouse position
sub UpdateCursor
  gui cursor mouse(X), mouse(Y)
end sub

' Handle mouse Left clicks
' Check mouse in board range or in the color squares at bottom.
' Check handshake flag left_busy. If not busy, then set click 
' flag and store mouse coordinates.
sub LClick
  local mx, my, i, x, sw
  if (left_busy = 1) or (is_running = 0) then exit sub
  mx = mouse(X) : my = mouse(Y)
  if mx >= theBoardX and mx <= theBoardX + theBoardWidth then
    if my >= theBoardY and my <= theBoardY + theBoardHeight then
      theMouseX = mx : theMouseY = my
      theRow = (my - theBoardY)\theCellSize + 1
      theCol = (mx - theBoardX)\theCellSize + 1
      left_click = 1
      exit sub
    end if
  end if
  if my >= PC_Y and my <= PC_Y+PC_H then
    sw = theNumColors*PC_W + (theNumColors-1)*PC_SPAC
    x = mm.hres\2 - sw\2
    for i = 1 to theNumColors
      if mx >= x and mx <= x+PC_W then
        theRow = -1
        theCol = -i
        left_click = 1
        exit sub
      end if
      inc x, (PC_W+PC_SPAC)
    next i
  end if
end sub

' Read the table of maximum moves per board size and number 
' of colors.
sub ReadNumMoves
  local size, nc
  for size = 1 to NSIZES
    for nc = 1 to NCOLORS
      read maxMoves(nc, size)
    next nc
  next size
end sub

' Read the table of cell sizes per board size
sub ReadCellSizes
  local size
  for size = 1 to NSIZES
    read csizes(size)
  next size
end sub

' Read the table of cell colors
sub ReadColors
  local i
  for i = 1 to MAXCOLORS
    read colors(i)
  next i
end sub

' Show the starting screen with instructions
sub ShowStartScreen
  local z$
  local cmd
  cls
  gui cursor hide
  text mm.hres\2, 10, "FloodIt!", "CT", 5, 1, rgb(green)
  text 0, 80, ""
  print "Floodit starts with a square made up of smaller squares filled with random colors"
  print "You get to choose the outer square's dimension from 6x6 up to 26x26. You also get"
  print "to choose how many colors are used to fill the smaller squares, from 3 to 8."
  print "Starting at the top left corner of the larger square, your job is to choose some"
  print "color out of the available ones. If that color is adjacent to the top left small"
  print "square, it will change to your chosen color, and so will all the other adjacent"
  print "squares of the same color as the top left color. You continue choosing colors, and"
  print "the flood fill will gradually increase in size.
  print ""
  print "Your task is to flood the entire large square with one color, but you are only given"
  print "a limited number of moves to do it. If you have some small squares of a different"
  print "color left over, you lose!
  print ""
  print "You get one score point if you complete with the maximum number of moves, four if you"
  print "complete with one less than the maximum, 9 if you are 2 under, 16 for 3 under, and so"
  print "on... in other words, the square of one more than your margin.
  print ""
  print "If you are playing without a mouse, use the LEFT and RIGHT arrow keys to move the"
  print "cursor back and forth among the large color squares at the bottom. Press ENTER to"
  print "make a move with that color. You want to pick a color that is adjacent to the growing"
  print "flood region."
  print ""
  print "If you are using a mouse, you can use the color squares by clicking on them, but you"
  print "will likely prefer to click directly on the board, since it makes it easier to find"
  print "a better move. Just remember, you are really choosing a color, not a specific location."

  text mm.hres\2, 500, "Press Any Key to Play or Escape to Quit", "CT"
  z$ = INKEY$
  do
    z$ = INKEY$
  loop until z$ <> ""
  cmd = asc(UCASE$(z$))
  select case cmd
    case ESC
      Quit
    case else
      ' Pass
  end select
  gui cursor show
end sub

' Quit the game
sub Quit
  cls
  if hasMouse then
    gui cursor hide
    settick 0,0
    controller mouse close 2
  end
end sub

' Let the use choose the board size and number of colors
sub ChooseParams
  local i, x, y, w, h, s, cmd, cpos, nc, which, size
  local m$, z$
  cls
  if theSizeIndex > 0 then
    cpos = theSizeIndex
  else
    cpos = 1
  end if
  DrawSizes cpos, 1
  if theNumColorIndex > 0 then
    nc = theNumColorIndex
  else
    nc = 1
  end if
  DrawColors nc, 0
  which = 1
  text mm.hres\2, 10, "Choose Parameters", "CT", 5,, rgb(green)
  print @(80, 210);"Use the LEFT and RIGHT arrow keys to select a size and color. Use the UP"
  print @(80, 225);"and DOWN keys to toggle between choosing a size and choosing the number"
  print @(80, 240);"of colors. Press ENTER to play or ESCAPE to quit."
  do
    z$ = INKEY$
    do
      z$ = INKEY$
    loop until z$ <> ""
    cmd = asc(UCASE$(z$))
    select case cmd
      case UP, DOWN
        which = 1-which
        DrawSizes cpos, which
        DrawColors nc, 1-which
      case LEFT
        if which = 1 then
          if cpos > 1 then
            inc cpos, -1
          else
            cpos = NSIZES
          end if
          DrawSizes cpos, which
        else
          if nc > 1 then
            inc nc, -1
          else
            nc = NCOLORS
          end if
          DrawColors nc, 1-which
        end if
      case RIGHT
        if which = 1 then
          if cpos < NSIZES then
            inc cpos
          else
            cpos = 1
          end if
          DrawSizes cpos, which
        else
          if nc < NCOLORS then
            inc nc
          else
            nc = 1
          end if
          DrawColors nc, 1-which
        end if
      case ENTER
        theSizeIndex = cpos
        theNumColorIndex = nc
        exit do
      case ESC
        Quit
    end select
  loop
end sub

' show the available board sizes
sub DrawSizes cpos, hilite
  local i, x, y, w, h, s, c, t
  local m$
  w = 80 : h = 80
  for i = 1 to NSIZES
    s = sizes(i)
    x = 60 + (i-1)*130
    y = 100
    c = rgb(white)
    t = 1
    if i = cpos then 
      c = rgb(yellow)
      t = 3
    end if
    box x, y, w, h,, rgb(black), rgb(black)
    box x, y, w, h, t, c
    m$ = str$(s) + "x" + str$(s)
    text x+w\2, y+h\2, m$, "CM",,, rgb(yellow)
  next i
  if hilite then
    c = rgb(red)
  else
    c = rgb(black)
  end if
  DrawArrow 2, y+30, c
end sub

' show the available number of colors and the colors themselves
sub DrawColors nc, hilite
  local i, j, x, y, w, h, s, c, t, bw, bh
  local cx, cy
  local m$
  w = 20 : h = 20
  y = 300
  bw = 4*w : bh = 2*h
  for i = 1 to MAXCOLORS-MINCOLORS+1
    x = 60 + (i-1)*(BW+50)
    t = 1
    c = rgb(white)
    if i = nc then
      t = 3
      c = rgb(yellow)
    end if
    box x-3, y-3, bw+6, bh+6, 1, rgb(black), rgb(black)
    box x-3, y-3, bw+6, bh+6, t, c
    m$ = str$(i+MINCOLORS-1) + " Colors"
    text x+bw\2, y-4, m$, "CB"
    cx = x
    cy = y
    for j = 1 to MAXCOLORS
      c = colors(j)
      if j > i+MINCOLORS-1 then
        c = rgb(black)
      end if
      box cx, cy, w, h, 1, rgb(black), c
      inc cx, w
      if cx = x+4*w then cx = x
      if j = MAXCOLORS\2 then inc cy, h
    next j        
  next i
  if hilite then
    c = rgb(red)
  else
    c = rgb(black)
  end if
  DrawArrow 2, y+20, c
end sub

' Hilite the active parameter choice
sub DrawArrow x, y, c
  local xv(7), yv(7)
  local p = 10
  xv(1) = x     : yv(1) = y-p\2
  xv(2) = x+3*p : yv(2) = yv(1)
  xv(3) = xv(2) : yv(3) = y-1.5*p
  xv(4) = x+5*p : yv(4) = y
  xv(5) = xv(3) : yv(5) = y+1.5*p
  xv(6) = xv(5) : yv(6) = y+p\2
  xv(7) = x     : yv(7) = yv(6)
  polygon 7, xv(), yv(), c, c
end sub

' Initialize game parameters
sub InitGame 
  local row, col
  theMaxMoves = maxMoves(theNumColorIndex, theSizeIndex)
  theNumColors = theNumColorIndex+MINCOLORS-1
  theCellSize = csizes(theSizeIndex)
  size = sizes(theSizeIndex)
  theBoardSize = size
  theBoardWidth = size*theCellSize
  theBoardHeight = theBoardWidth
  theBoardX =  mm.hres\2 - theBoardWidth/2
  theBoardY = TOP_MARGIN
  erase theBoard
  dim theBoard(theBoardSize, theBoardSize)
  for row = 1 to size
    for col = 1 to size
      theBoard(col, row) = 0
    next col
  next row
  num_user_moves = 0
  is_won = 0
  is_filled = 0
  is_running = 1
end sub

' Draw the playing board, given the size and number of colors
sub DrawBoard
  local row, col, x, y, w, size, cx
  local i, sw, sm
  cls
  size = theBoardSize
  for row = 1 to size
    y = theBoardY + (row-1)*theCellSize
    for col = 1 to size
      x = theBoardX + (col-1)*theCellSize
      cx = RandomIntegerInRange(1, theNumColors)
      theBoard(col, row) = cx
      c = colors(cx)
      box x, y, theCellSize, theCellSize, 1, c, c
    next col
  next row
  sw = theNumColors*PC_W + (theNumColors-1)*PC_SPAC
  x = mm.hres\2 - sw\2
  y = PC_Y
  for i = 1 to theNumColors
    box x, y, PC_W, PC_H,, rgb(white), colors(i)
    inc x, PC_W + PC_SPAC
  next i
end sub

' Look for user keyboard inputs when playing with a mouse
' (Currently, only ESCAPE is sensed). Look for flag showing
' a mouse click in the board range. Set the busy flag and
' do the move.
sub GetUserInputs
  local z$
  local cmd, cx
  ShowScore
  do
    if left_click = 1 then
      left_busy = 1
      left_click = 0
      if theCol > 0 then
        cx = theBoard(theCol, theRow)
      else
        cx = -theCol
      end if
      DoMove cx
      left_busy = 0
    end if
    z$ = INKEY$
    if z$ <> "" then
      if not is_running then exit do
      cmd = asc(UCASE$(z$))
      select case cmd
        case ESC
          Quit
      end select
      z$ = ""
    end if
  loop
end sub

' Play loop for playing without a mouse
sub PlayLoop nc
  local z$
  local cmd, cindex
  cindex = 1
  gui cursor colour rgb(black)
  ControlCursor cindex
  do
    z$ = INKEY$
    do
      z$ = INKEY$
    loop until z$ <> ""
    cmd = asc(UCASE$(z$))
    select case cmd
      case LEFT
        if cindex > 1 then
          inc cindex, -1
        end if
        ControlCursor cindex
      case RIGHT
        if cindex < theNumColors then
          inc cindex
          ControlCursor cindex
        end if
      case ENTER
        left_busy = 1
        DoMove cindex
        left_busy = 0
      case ESC
        Quit
    end select
  loop
end sub

' Move the cursor around according to user inputs when playing
' without a mouse.
sub ControlCursor cindex
  local cx, cy
  cy = PC_Y + PC_H\2
  sw = theNumColors*PC_W + (theNumColors-1)*PC_SPAC
  cx = mm.hres\2 - sw\2 + (cindex-1)*(PC_W+PC_SPAC) + PC_W\2
  gui cursor cx, cy  
end sub

' Perform a move changing the flood color to the color at
' colors(cx)
sub DoMove cx
  local fx, fy, bx, c
  bx = theBoard(1,1)  
  if cx <> bx then
    theBoard(1, 1) = cx
    c = colors(cx)
    fx = theBoardX + theCellSize\2
    fy = theBoardY + theCellSize\2
    gui cursor hide
    pixel fill fx, fy, c
    gui cursor show
    inc num_user_moves
if num_user_moves = 18 then save image "Floodit"
    ShowScore
  end if
end sub

' Check for a Completely Filled Board
function CheckFilled()
  local row, col, fc, c, x, y
  fc = 0
  for row = 1 to theBoardSize
    y = theBoardY + (row-1)*theCellSize + theCellSize\2
    for col = 1 to theBoardSize
      x = theBoardX + (col-1)*theCellSize + theCellSize\2
      c = pixel(x, y)
      if fc = 0 then fc = c
      if c <> fc then
        CheckFilled = 0
        exit function
      end if
    next col
  next row
  CheckFilled = 1
end function

' Show the moves and the score
sub ShowScore
  local m$
  if CheckFilled() then
    is_filled = 1
    is_running = 0
  end if
  if num_user_moves >= theMaxMoves then
    is_running = 0
    if is_filled then
      is_won = 1
    end if
  else
    if is_filled then
      is_won = 1
    end if
  end if   
  if is_running = 0 then
    inc num_games
  end if
  m$ = str$(num_user_moves) + " / " + str$(theMaxMoves) + " moves"
  text SCORE_X, SCORE_Y, m$
  if is_running = 0 then
    if is_won then
      m$ = "You win!"
      score = (theMaxMoves - num_user_moves + 1)^2
      inc cumulative_score, score
    else
      m$ = "You lose"
      score = 0
    end if
    text SCORE_X, SCORE_Y+20, m$
    m$ = "Score " + str$(score)
    text SCORE_X, SCORE_Y+40, m$
    m$ = "Cumulative Score " + str$(cumulative_score)
    text SCORE_X, SCORE_Y+60, m$
    text SCORE_X, SCORE_Y+80, "Press Any Key"
  end if
end sub
    
' Return uniformly distributed random integer in a closed range,
function RandomIntegerInRange(a, b)
  local v, c
  do
    c = b-a+1
    v = a + (b-a+2)*rnd(c)
    if v >= a and v <= b then exit do
  loop
  RandomIntegerInRange = v
end function

' Max moves per size (row) and number of colors (col)
data  5,  7,  8, 10, 12, 14
data  8, 11, 14, 17, 20, 23
data 12, 16, 20, 25, 29, 38
data 16, 21, 26, 32, 37, 42
data 19, 26, 32, 39, 45, 52
data 23, 30, 38, 46, 54, 61

' Cell sizes per board size (sizes need to be even)
data 40, 30, 24, 20, 18, 14

' Cell Colors
data rgb(0, 255, 0)     'green
data rgb(255, 255, 0)   'yellow
data rgb(255, 0, 0)     'red
data rgb(200, 145, 75)  'tan
data rgb(88, 0, 122)    'purple
data rgb(0, 255, 255)   'cyan
data rgb(0, 0, 255)     'blue
data rgb(255, 0, 255)   'magenta

