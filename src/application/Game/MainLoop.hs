{-# language ScopedTypeVariables #-}

-- | The (real) main (that is, entry-) module for the game

module Game.MainLoop (
    logicLoop,
    GameState(..),
    initialStateRef,
    initialState
  ) where


import Data.Set as Set (Set, empty, insert, delete, toList)
import Data.IORef

import Control.Monad.State hiding ((>=>))
import Control.Concurrent

import System.Random

import GHC.Conc

import Physics.Chipmunk as CM

import Graphics.Qt

import Utils

import Base.Events
import Base.FPSState
import Base.Constants
import Base.Types
import Base.PhysicsProfiling

import Object

import Game.Scene

import Top.Application


-- prints the version number of qt and exits
debugQtVersion :: IO ()
debugQtVersion = do
    v <- qVersion
    putStrLn ("Qt-Version: " ++ v)

-- prints the number of HECs (see haskell concurrency)
debugNumberOfHecs :: IO ()
debugNumberOfHecs =
    putStrLn ("Number of HECs: " ++ show numCapabilities)



-- * running the state monad inside the render IO command
-- renderCallback :: Application -> IORef GameAppState -> [QtEvent] -> Ptr QPainter -> IO ()
-- renderCallback app stateRef qtEvents painter = do
--     let allEvents = toEitherList qtEvents []
-- 
--     state <- readIORef stateRef
--     ((), state') <- runStateT (renderWithState app painter) state
--     writeIORef stateRef state'

-- Application Monad and State

type AppMonad o = StateT GameState IO o

data GameState = GameState {
    keyState :: Set AppButton,
    cmSpace :: CM.Space,
    scene :: Scene Object_,
    timer :: Ptr QTime
  }

setKeyState :: GameState -> Set AppButton -> GameState
setKeyState s x = s{keyState = x}
setScene :: GameState -> Scene Object_ -> GameState
setScene s x = s{scene = x}

initialStateRef :: Ptr QApplication -> Ptr AppWidget -> (CM.Space -> IO (Scene Object_))
    -> IO (IORef GameState)
initialStateRef app widget scene = initialState app widget scene >>= newIORef

initialState :: Ptr QApplication -> Ptr AppWidget -> (CM.Space -> IO (Scene Object_)) -> IO GameState
initialState app widget startScene = do
    cmSpace <- initSpace gravity
    scene <- startScene cmSpace
    qtime <- newQTime
    startQTime qtime
    return $ GameState Set.empty cmSpace scene qtime



-- State monad command for rendering (for drawing callback)
-- logicLoop :: Application -> MVar (Scene Object_) -> Seconds -> AppMonad AppState
logicLoop app sceneMVar = do
    timer_ <- gets timer
    startTime <- liftIO $ elapsed timer_
    -- input events
    qtEvents <- liftIO $ pollEvents $ keyPoller app
    let events = toEitherList qtEvents []
    oldKeyState <- gets keyState
    let appEvents = concatMap (toAppEvent oldKeyState) events
    heldKeys <- actualizeKeyState appEvents

    -- stepping of the scene (includes rendering)
    space <- gets cmSpace
    sc <- gets scene
    sc' <- liftIO $ stepScene space (ControlData appEvents heldKeys) sc

    liftIO $ swapMVar sceneMVar $ unmutableCopy sc'

    puts setScene sc'
    case mode sc' of
        LevelFinished _ x -> return FinalState
        _ -> do
            waitPhysics startTime
            logicLoop app sceneMVar

-- | Waits till the real world catches up with the simulation.
-- Since 'threadDelay' seems to be far to inaccurate, we have a busy wait :(
-- TODO
waitPhysics :: Int -> AppMonad ()
waitPhysics startTime = gets timer >>= \ timer_ -> liftIO $ do
    let loop n = do
            now <- elapsed timer_
            if (now - startTime < round (stepQuantum * 1000)) then
                loop (n + 1)
              else
                return n
    n <- loop 0
    tickBusyWaitCounter n


-- Well, this isn't really an unmutable copy. Maybe we can get away without.
unmutableCopy :: Scene Object_ -> Scene Object_
unmutableCopy = id


-- | returns the time passed since program start
getSecs :: AppMonad Double
getSecs = do
    qtime <- gets timer
    time <- liftIO $ elapsed qtime
    return (fromIntegral time / 10 ^ 3)


actualizeKeyState :: [AppEvent] -> AppMonad [AppButton]
actualizeKeyState events = do
    modifies keyState setKeyState (chainApp inner events)
    fmap toList $ gets keyState
  where
    inner :: AppEvent -> Set AppButton -> Set AppButton
    inner (Press k) ll = insert k ll
    inner (Release k) ll = delete k ll






