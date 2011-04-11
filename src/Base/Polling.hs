
module Base.Polling where


import Data.Set (Set, insert, empty, delete)
import Data.IORef

import Control.Concurrent
import Control.Arrow

import System.IO.Unsafe
import System.Info

import Graphics.Qt

import Utils

import Base.Types
import Base.GlobalShortcuts


-- this is for joystick (and gamepad) stuff, will be used soon!
type JJ_Event = ()

{-# NOINLINE keyStateRef #-}
keyStateRef :: IORef ([AppEvent], Set Button)
keyStateRef = unsafePerformIO $ newIORef ([], empty)

-- | non-blocking polling of AppEvents
-- Also handles global shortcuts.
pollAppEvents :: Application_ s -> M ControlData
pollAppEvents app = do
    (unpolledEvents, keyState) <- io $ readIORef keyStateRef
    qEvents <- io $ pollEvents $ keyPoller app
    appEvents <- handleGlobalShortcuts app keyState $
        map (toAppEvent keyState . Left) qEvents
    let keyState' = foldr (>>>) id (map updateKeyState appEvents) keyState
    io $ writeIORef keyStateRef ([], keyState')
    return $ ControlData (unpolledEvents ++ appEvents) keyState'

-- | puts AppEvents back to be polled again
unpollAppEvents :: [AppEvent] -> IO ()
unpollAppEvents events = do
    (unpolledEvents, keyState) <- readIORef keyStateRef
    writeIORef keyStateRef (unpolledEvents ++ events, keyState)

resetHeldKeys :: IO ()
resetHeldKeys = do
    modifyIORef keyStateRef (second (const empty))


-- | Blocking wait for the next event.
-- waits between polls
waitForAppEvent :: Application_ s -> M AppEvent
waitForAppEvent app = do
    ControlData events _ <- pollAppEvents app
    case events of
        (a : r) -> io $ do
            unpollAppEvents r
            return a
        [] -> do
            io $ threadDelay (round (0.01 * 10 ^ 6))
            waitForAppEvent app

-- | Blocks until a Press AppEvent is received.
waitForPressAppEvent :: Application_ s -> M AppEvent
waitForPressAppEvent app = do
    e <- waitForAppEvent app
    case e of
        (Press _) -> return e
        _ -> waitForPressAppEvent app

updateKeyState :: AppEvent -> Set Button -> Set Button
updateKeyState (Press   k) ll = insert k ll
updateKeyState (Release k) ll = delete k ll
updateKeyState Base.Types.CloseWindow ll = ll


toAppEvent :: Set Button -> Either QtEvent JJ_Event -> AppEvent
-- keyboard
toAppEvent _ (Left (KeyPress key string)) = Press $ KeyboardButton key string
toAppEvent _ (Left (KeyRelease key string)) = Release $ KeyboardButton key string

toAppEvent _ (Left Graphics.Qt.CloseWindow) = Base.Types.CloseWindow

-- joystick
-- toAppEvent _ (Right (JoyButtonDown 0 jbutton)) | jbutton `member` jbutton2button =
--     [Press   (jbutton2button ! jbutton)]
-- toAppEvent _ (Right (JoyButtonUp   0 jbutton)) | jbutton `member` jbutton2button =
--     [Release (jbutton2button ! jbutton)]
-- toAppEvent oldButtons (Right (JoyHatMotion  0 0 x)) =
--     calculateJoyHatEvents oldButtons x
