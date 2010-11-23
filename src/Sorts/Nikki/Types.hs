{-# language FlexibleInstances, DeriveDataTypeable #-}

module Sorts.Nikki.Types where


import Prelude hiding (lookup)

import Data.Map (Map)
import Data.Generics
import Data.Initial

import Control.Arrow

import Graphics.Qt as Qt hiding (rotate, scale)

import Sound.SFML

import Physics.Chipmunk hiding (position, Position)

import Utils

import Base.Types
import Base.Constants
import Base.Directions
import Base.Pixmap


data NSort = NSort {
    pixmaps :: Map String [Pixmap],
    jumpSound :: PolySound
  }
    deriving (Show, Typeable)

data Nikki
    = Nikki {
        chipmunk :: Chipmunk,
        feetShape :: Shape,
        state :: State,
        startTime :: Seconds, -- time the State was last changed
        batteryPower :: Integer -- makes it possible to have REALLY BIG amounts of power :)
      }
  deriving (Show, Typeable)

-- | just for compatibility (TODO: remove)
feetShapes :: Nikki -> [Shape]
feetShapes = return . feetShape

instance Show (Ptr QPainter -> Offset Double -> IO ()) where
    show _ = "<Ptr QPainter -> Offset Double -> IO ()>"

addBatteryPower :: Nikki -> Nikki
addBatteryPower n = n{batteryPower = batteryPower n + 1}




data State = State {
    action :: Action,
    direction :: HorizontalDirection -- the direction nikki faces
  }
    deriving (Show)

instance Initial State where
    initial = State Wait HLeft

data Action
    = Wait
    | Walk
        -- state for one frame (when a jump starts)
    | JumpImpulse Shape Angle JumpInformation
                               -- ghost jumping impulse
    | Airborne JumpInformation -- (Maybe (Shape, Angle))
    | WallSlide JumpInformation [Angle] [Cloud]
    | UsingTerminal
    | SlideToGrip JumpInformation
    | Grip -- when Nikki uses the paws to hold on to something
    | EndGripImpulse -- state for one frame (when grip state is ended)
    | Touchdown
    | NikkiLevelFinished LevelResult
  deriving (Show)

toActionNumber Wait = 0
toActionNumber Walk = 1
toActionNumber JumpImpulse{} = 2
toActionNumber Airborne{} = 3
toActionNumber WallSlide{} = 4
toActionNumber UsingTerminal = 5
toActionNumber SlideToGrip{} = 6
toActionNumber Grip = 7
toActionNumber EndGripImpulse = 8
toActionNumber Touchdown = 9
toActionNumber NikkiLevelFinished{} = 10

isSlideToGrip :: State -> Bool
isSlideToGrip state = toActionNumber (action state) == 6

isAirborneAction :: Action -> Bool
isAirborneAction = (3 ==) . toActionNumber

isTouchdownAction :: Action -> Bool
isTouchdownAction = (9 ==) . toActionNumber


getJumpInformation :: Action -> Maybe JumpInformation
getJumpInformation (Airborne x) = Just x
getJumpInformation (WallSlide x _ _) = Just x
getJumpInformation (SlideToGrip x) = Just x
getJumpInformation (JumpImpulse _ _ x) = Just x
getJumpInformation _ = Nothing

data JumpInformation =
    JumpInformation {
        jumpStartTime :: Maybe Seconds,
        jumpNikkiVelocity :: Velocity,
        jumpButtonDirection :: (Maybe HorizontalDirection)
      }
  deriving (Show)

data Cloud
    = Cloud {
        creationTime :: Seconds,
        cloudPosition :: Qt.Position Double
      }
  deriving (Show)
