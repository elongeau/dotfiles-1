import XMonad hiding ((|||))
import XMonad.Actions.CycleRecentWS
import XMonad.Actions.PerLayoutKeys
import XMonad.Actions.UpdatePointer
import XMonad.Actions.WindowNavigation
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.FadeInactive
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.Accordion
import XMonad.Layout.Combo
import qualified XMonad.Layout.GridVariants as G
import XMonad.Layout.LayoutCombinators
import XMonad.Layout.Named
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Reflect
import XMonad.Layout.StackTile
import XMonad.Layout.Tabbed
import XMonad.Layout.TwoPane
import XMonad.Prompt
import XMonad.Util.EZConfig
import XMonad.Util.Run(spawnPipe)
import XMonad.Util.Scratchpad

import qualified XMonad.StackSet as W

import Control.Monad (liftM2)
import Data.List
import Data.Ratio
import System.IO

myLayout = avoidStrutsOn[U] $
    onWorkspace "2:im/mail"  (named "Grid" tallgrid ||| named "Tabbed" tabs) $
    onWorkspace "3:media"    (named "Tabbed" tabs) $
    onWorkspace "4:vbox"     Full $
    onWorkspace "5:misc"     (named "Tabbed" tabs) $
    onWorkspace "6:misc"     (named "Tabbed" tabs) $
    named "Accordian/Full"   accordianFull |||
    named "Tiled"            tiled |||
    named "Tabbed"           tabs
  where
    accordianFull = (combineTwo (TwoPane (3/100) (1/2)) (Accordion) (Full))
    tabs          = reflectHoriz $ tabbed shrinkText myTabConfig
    tallgrid      = G.SplitGrid G.T 1 2 (1/2) (10/10) (5/100)
    tiled     = reflectHoriz $ Tall 1 (3/100) (1/2)
    myTabConfig = defaultTheme {
      activeColor = "#222222",
      activeTextColor = "#aaaaaa",
      activeBorderColor = "#395571",
      inactiveColor = "#222222",
      inactiveTextColor = "#666666",
      inactiveBorderColor = "#343434",
      urgentColor = "#222222",
      urgentBorderColor = "#343434",
      urgentTextColor = "#bb4b4b"}

manageScratchPad :: ManageHook
manageScratchPad = scratchpadManageHook (W.RationalRect l t w h)
  where
    h = 0.1     -- terminal height, 10%
    w = 1       -- terminal width, 100%
    t = 1 - h   -- distance from top edge, 90%
    l = 1 - w   -- distance from left edge, 0%

avoidMaster :: W.StackSet i l a s sd -> W.StackSet i l a s sd
avoidMaster = W.modify' $ \c -> case c of
    W.Stack t [] (r:rs) ->  W.Stack t [r] rs
    otherwise           -> c

myManageHook = composeAll [
    currentWs =? "1:main"          --> doF avoidMaster,
    name      =? "irssi"           --> viewShift "2:im/mail",
    name      =? "mutt"            --> viewShift "2:im/mail",
    name      =? "player"          --> viewShift "3:media",
    className =? "Gimp"            --> viewShift "3:media",
    className =? "VirtualBox"      --> viewShift "4:vbox",
    className =? "nxclient"        --> viewShift "4:vbox",
    -- gimp insists on floating, so prevent that.
    role =? "gimp-image-window"    --> ask >>= doF . W.sink
  ] <+> manageScratchPad
  where
    name = stringProperty "WM_NAME"
    role = stringProperty "WM_WINDOW_ROLE"
    viewShift = doF . liftM2 (.) W.view W.shift

barFont = "-*-terminus-*-r-normal-*-*-120-*-*-*-*-iso8859-*"
barBackground = "#232323"
barForeground = "#7e7e7e"

myXPConfig = defaultXPConfig {
  font = barFont,
  bgColor = "#222222",
  fgColor = "#aaaaaa",
  borderColor = "#395571",
  historyFilter = deleteAllDuplicates}

myTerminal = "urxvt"
myWorkspaces = ["1:main", "2:im/mail", "3:media", "4:vbox", "5:misc", "6:misc"]

noScratchPad ws = if ws == "NSP" then "" else ws

main = do
  xmproc <- spawnPipe ("~/bin/dzen2 -wp 45 -ta l -h 16 -x 0 -y 0")
  config <-
    withWindowNavigation(xK_k, xK_h, xK_j, xK_l) $
    withUrgencyHook NoUrgencyHook $
    defaultConfig {
      borderWidth        = 1,
      modMask            = mod1Mask,
      terminal           = myTerminal,
      normalBorderColor  = "#333333",
      focusedBorderColor = "#5884b0",
      workspaces         = myWorkspaces,
      manageHook         = manageDocks <+> myManageHook <+> manageHook defaultConfig,
      layoutHook         = myLayout,
      startupHook        = setWMName "LG3D", -- pre java 7 workaround for some apps
      focusFollowsMouse = False,
      logHook            = dynamicLogWithPP dzenPP {
        ppOutput  = hPutStrLn xmproc,
        ppSep     = " | ",
        ppCurrent = dzenColor "#5884b0" barBackground . wrap " [" "] ",
        ppVisible = dzenColor "#58738d" barBackground . wrap " " " ",
        ppHidden  = dzenColor barForeground barBackground . wrap " " " " . noScratchPad,
        ppLayout  = dzenColor barForeground barBackground . wrap "{ " " }",
        ppTitle   = dzenColor "#8eb157" barBackground . shorten 75,
        ppUrgent  = dzenColor "#bb4b4b" barBackground . dzenStrip
      } >> fadeInactiveLogHook 0.5 >> updatePointer (Relative 0.97 0.97)
    }
    -- change workspace keybindings to not be "greedy" (move my focus to the
    -- screen displaying the workspace instead of moving the workspace to my
    -- screen)
    `additionalKeys` [((m .|. mod1Mask, k), windows $ f i)
         | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
         , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    `additionalKeysP` [
      ("M-x",       kill),
      ("M-m",       sendMessage $ JumpToLayout "Tabbed"),
      ("M-u",       focusUrgent),
      ("M-w",       cycleRecentWS [xK_Alt_L] xK_Tab xK_Tab),
      ("M-<Tab>",   bindOnLayout [
                        ("Tabbed", windows W.focusUp),
                        ("", windows W.focusDown)]),
      ("M-S-<Tab>", bindOnLayout [
                        ("Tabbed", windows W.focusDown),
                        ("", windows W.focusUp)]),
      ("M-S-s",     withFocused $ windows . W.sink),
      ("M-p",       scratchpadSpawnActionTerminal myTerminal),
      ("M-t",       spawn $ "pkill stalonetray || stalonetray -bg '#232323' -i 16"),
      ("M-z",       spawn $ "alock -cursor theme:name=xtr -auth pam"),
      ("M-S-C-s",   spawn $ "~/bin/shutdown gui"),
      ("M-q",       spawn $ "xmonad --restart; pkill xcompmgr && xcompmgr -c -r0 &"),
      -- toggle between programmers dvorak and us qwerty
      ("M-<F1>",    spawn $ "(setxkbmap -query | grep -q 'layout:\\s\\+us') " ++
                            "&& setxkbmap dvp || setxkbmap us"),
      -- audio keys
      ("M-S-<Right>",       spawn $ "~/bin/player toggle"),
      ("M-<Right>",         spawn $ "~/bin/player next"),
      ("M-<Left>",          spawn $ "~/bin/player prev"),
      ("M-S-<Up>",          spawn $ "~/bin/volume toggle"),
      ("M-<Up>",            spawn $ "~/bin/volume 3+"),
      ("M-<Down>",          spawn $ "~/bin/volume 3-") ]
    `removeKeysP` [ ("M-r") ]

  xmonad config
