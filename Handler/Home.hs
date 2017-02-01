module Handler.Home where

import Import
import System.Process
import System.IO.Unsafe
import Data.Time
import Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)

getHomeR :: Handler Html
getHomeR = do
    defaultLayout
      $(widgetFile "homepage")
