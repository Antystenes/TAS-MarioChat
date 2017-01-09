-- | Common handler functions.
module Handler.Common where

import System.IO.Unsafe (unsafePerformIO)
import Yesod.Auth.HashDB
import Data.FileEmbed (embedFile)
import Import
import qualified Yesod.Auth.Message as Msg

-- These handlers embed files in the executable at compile time to avoid a
-- runtime dependency, and for efficiency.

getFaviconR :: Handler TypedContent
getFaviconR = do cacheSeconds $ 60 * 60 * 24 * 30 -- cache for a month
                 return $ TypedContent "image/x-icon"
                        $ toContent $(embedFile "config/favicon.ico")

getRobotsR :: Handler TypedContent
getRobotsR = return $ TypedContent typePlain
                    $ toContent $(embedFile "config/robots.txt")

regForm :: Html -> MForm Handler(FormResult User, Widget)
regForm = renderDivs $ User
  <$> areq textField "Username" Nothing
  <*> areq passwordField "Password" Nothing
  --where pswd1 = FieldSettings (SomeMessage Msg.Password) Nothing Nothing Nothing []

getRegR :: Handler Html
getRegR = do
  (widget, enctype) <- generateFormPost regForm
  defaultLayout
    [whamlet|
            <form method=post action=@{RegR} enctype=#{enctype}>
                ^{widget}
                <button> Zarejestruj
    |]

postRegR :: Handler Html
postRegR = do
  ((result, widget), enctype) <- runFormPost regForm
  case result of
    FormSuccess user -> do runDB $ insert ( unsafePerformIO $ setPassword (userPassword user) user)
                           defaultLayout
                             [whamlet|
                                     <p> Successfully added user
                                     |]
--                           redirect RedirectSeeOther HomeR
    _ -> defaultLayout
            [whamlet|
                <p>Invalid input, let's try again.
                <form method=post action=@{RegR} enctype=#{enctype}>
                    ^{widget}
                    <button>Submit
            |]
