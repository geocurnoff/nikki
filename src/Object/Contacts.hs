{-# language NamedFieldPuns #-}

module Object.Contacts (
    MyCollisionType(..),
    watchedContacts,

    Contacts(..),
    nikkiTouchesTerminal,
  ) where


import Data.Set as Set hiding (map)
import Data.Initial

import Physics.Chipmunk

import Utils

import Base.Types


nikkiCollisionTypes = [NikkiLegsCT, NikkiHeadCT, NikkiLeftPawCT]

nikkiPermeability NikkiLeftPawCT = Permeable
nikkiPermeability _ = Solid

-- | collision types of objects that cause a collision (that are solid) (without Nikkis collision types)
solidCollisionTypes :: [MyCollisionType]
solidCollisionTypes =
  [
    TileCT,
    RobotCT,
    FallingTileCT
  ]


-- initial in the sense that nothing collides
instance Initial Contacts where
    initial = Contacts [] False empty empty empty empty


-- * setter (boolean to True)

addNikkiContacts :: Shape -> MyCollisionType -> Vector -> Contacts -> Contacts
addNikkiContacts s ct v c =
    c{nikkiCollisions = (NikkiCollision s v ct : nikkiCollisions c)}

setNikkiTouchesLaser :: Contacts -> Contacts
setNikkiTouchesLaser c = c{nikkiTouchesLaser = True}

addTrigger :: Shape -> Contacts -> Contacts
addTrigger s c = c{triggers = insert s (triggers c)}

addTerminal :: Shape -> Contacts -> Contacts
addTerminal terminalShape c@Contacts{terminals} =
    c{terminals = insert terminalShape terminals}

nikkiTouchesTerminal :: Contacts -> Bool
nikkiTouchesTerminal = not . Set.null . terminals

addBattery :: Shape -> Contacts -> Contacts
addBattery batteryShape c =
    c{batteries = insert batteryShape (batteries c)}

addFallingTileContact :: Shape -> Contacts -> Contacts
addFallingTileContact fallingTileShape contacts =
    contacts{fallingTiles = insert fallingTileShape (fallingTiles contacts)}



watchedContacts :: [Callback MyCollisionType Contacts]
watchedContacts =
    -- normal contacts of nikki
    map (uncurry nikkiCallbacks) (cartesian solidCollisionTypes nikkiCollisionTypes) ++
    switchCallback :
    nikkiTerminalCallbacks ++
    map terminalSolidCallback solidCollisionTypes ++
    map batteryCallback nikkiCollisionTypes ++
    Callback (DontWatch BatteryCT TerminalCT) Permeable :
    map nikkiFallingTilesCallbacks nikkiCollisionTypes


nikkiCallbacks solidCT nikkiCollisionType =
    Callback
        (FullWatch
            solidCT
            nikkiCollisionType
            (\ shape _ -> addNikkiContacts shape nikkiCollisionType))
        (nikkiPermeability nikkiCollisionType)

-- nikki stands in front of a terminal 
nikkiTerminalCallbacks =
    map
        (\ nct -> Callback (Watch nct TerminalCT (\ _ t -> addTerminal t)) Permeable)
        nikkiCollisionTypes

batteryCallback nikkiCT =
    Callback (Watch nikkiCT BatteryCT (\ _ b -> addBattery b)) Permeable

-- a trigger (in a switch) is activated
switchCallback =
    Callback (Watch TileCT TriggerCT (\ _ t -> addTrigger t)) Permeable

terminalSolidCallback solidCT =
    Callback (DontWatch TerminalCT solidCT) Permeable

-- contact with nikki and falling tiles
nikkiFallingTilesCallbacks nct =
    Callback (FullWatch FallingTileCT nct
        (\ a b v -> addFallingTileContact a . addNikkiContacts a nct v)) (nikkiPermeability nct)
