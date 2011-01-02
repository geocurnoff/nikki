{-# language DeriveDataTypeable #-}

module Base.Configuration where


import System.Console.CmdArgs

import Version


-- * dynamic configuration

data Configuration = Configuration {
    -- user config
    fullscreen :: Bool,
    noUpdate :: Bool,

    -- development
    runInPlace :: Bool,
    graphicsProfiling :: Bool,
    omitPixmapRendering :: Bool,
    renderXYCross :: Bool,
    renderChipmunkObjects :: Bool
  }
    deriving (Show, Data, Typeable)


getConfiguration :: IO Configuration
getConfiguration = do
    r <- cmdArgs options
    putStrLn ("Nikki and the Robots (" ++ showVersion nikkiVersion ++ ")")
    return r

options :: Configuration
options =
    Configuration {
        fullscreen = False
            &= help "start the game in fullscreen mode",
        noUpdate = False
            &= help "don't attempt to update the game from the web",

        runInPlace = False
            &= groupname "Development flags"
            &= help "causes the game to look for the data files in ../data",
        graphicsProfiling = False
            &= help "output FPS for the rendering thread",
        omitPixmapRendering = False
            &= help "omit the normal pixmaps when rendering objects",
        renderXYCross = False
            &= name "X"
            &= help "render x and y axis",
        renderChipmunkObjects = False
            &= name "c"
            &= help "render red lines for physical objects"
      }
    &= program "nikki"
    &= summary ("Nikki and the Robots (" ++ showVersion nikkiVersion ++ ")")
    &= help "run the game"
    &= helpArg [explicit, name "h", name "help", groupname "Common flags"]
    &= versionArg [explicit, name "v", name "version"]
    &= details (
        "Nikki and the Robots is a 2D platformer from Joyride Laboratories." :
        "http://www.joyridelabs.de/" :
        [])
