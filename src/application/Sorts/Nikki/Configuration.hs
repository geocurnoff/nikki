

module Sorts.Nikki.Configuration where


import Prelude hiding (lookup)

import Data.List (sortBy)
import Data.Map (Map, fromList, toList, (!), lookup)
import Data.Set (member)
import Data.Abelian
import Data.Generics
import Data.Initial
import Data.Array.Storable
import Data.Maybe
import qualified Data.Set as Set

import Control.Monad
import Control.Arrow
import Control.Applicative ((<|>))

import System.FilePath

import Graphics.Qt as Qt hiding (rotate, scale)

import Sound.SFML

import qualified Physics.Chipmunk as CM
import Physics.Chipmunk hiding (position, Position)

import Paths
import Utils

import Base.Constants
import Base.Events
import Base.Directions
import Base.Animation
import Base.Pixmap
import Base.Types

import Object

import Sorts.Nikki.Types


-- physic

elasticity_ = 0.0

-- there are some values to fine tune the behaviour of nikki. The aim is to keep the number
-- of fine tuners small.

nikkiMass = 2.5

-- | friction for nikkis feet. The higher the friction,
-- the faster nikki will gain maximum walking speed.
nikkiFeetFriction = 0.35

-- | the friction of the head ( and the legs (without the feet))
headFriction = 0.1

-- | maximum walking speed (pixel per second)
walkingVelocity = fromUber 100.8 <<? "walkingVelocity"

-- | how strong the vertical force is while Nikki is airborne
-- in gravities
airBorneForceFactor = 1000 / gravity

-- | minimal jumping height (for calculating the impulse strength)
-- We have an air drag for nikki and that makes calculating the right forces
-- difficult. So this variable and maximalJumpingHeight are just estimates.
minimalJumpingHeight = fromKachel 0.7

-- | maximal jumping height (created with decreased gravity (aka anti-gravity force))
maximalJumpingHeight = fromKachel 3.5

-- | decides how strong the horizontal impulse is in case of a 90 degree wall jump
-- 0 - no horizontal impulse
-- 1 - same horizontal impulse as normal jumping impulse (pointing up)
walljumpHorizontalFactor :: Double
walljumpHorizontalFactor = 1

-- | Controls how Nikki's velocity gets decreased by wall jumps.
-- Must be >= 1.
-- 1      - the downwards velocity is eliminated while jumping
-- bigger - the downwards velocity has more and more influence
-- No matter how high the value, the downwards velocity gets always clipped, 
-- to avoid wall jumps that point downwards.
correctionSteepness = 1.001


-- animation times 

frameTimes :: State -> (String, [(Int, Seconds)])
frameTimes action = case action of
    State Wait HLeft -> ("wait_left", wait)
    State Wait HRight -> ("wait_right", wait)
    State Walk HLeft -> ("walk_left", walk)
    State Walk HRight -> ("walk_right", walk)
    State JumpImpulse{} HLeft -> ("jump_left", airborne)
    State JumpImpulse{} HRight -> ("jump_right", airborne)
    State Airborne{} HLeft -> ("jump_left", airborne)
    State Airborne{} HRight -> ("jump_right", airborne)
    State WallSlide{} HLeft -> ("wallslide_left", airborne)
    State WallSlide{} HRight -> ("wallslide_right", airborne)
    State Grip HLeft -> ("grip_left", singleFrame)
    State Grip HRight -> ("grip_right", singleFrame)

    x -> es "frameTimes" x
  where
    wait = zip
        (0 : cycle [1, 2, 1, 2, 1, 2, 1])
        (1 : cycle [1.5, 0.15, 3, 0.15, 0.1, 0.15, 1])
    walk = zip
        (cycle [0..3])
        (repeat 0.15)
    airborne = zip
       (0 : repeat 1)
       (0.6 : repeat 10)
    terminal = singleFrame
    grip = singleFrame
    singleFrame = repeat (0, 10)


statePixmaps :: Map String Int
statePixmaps = fromList [
    ("wait_left", 2),
    ("wait_right", 2),
    ("walk_left", 3),
    ("walk_right", 3),
    ("jump_left", 1),
    ("jump_right", 1),
    ("terminal", 0),
    ("terminal", 0),
    ("grip_left", 0),
    ("grip_right", 0),
    ("wallslide_left", 0),
    ("wallslide_right", 0)
  ]
