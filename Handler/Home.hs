module Handler.Home where

import Import
import Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)
import Yesod.WebSockets

chatApp :: WebSocketsT Handler ()
chatApp = do
    (_ , user) <- lift requireAuthPair
    let name = userIdent user
    sendTextData $ "Welcome, " <> name
    writeChan <- appChat <$> getYesod
    readChan <- atomically $ do
        writeTChan writeChan $ name <> " has joined the chat"
        dupTChan writeChan
    race_
        (forever $ atomically (readTChan readChan) >>= sendTextData)
        (sourceWS $$  mapM_C (\msg -> do
                               --(runDB $ insert (MessageLog msg (userIdent user)))
                               atomically $ writeTChan writeChan $ name <> ": " <> msg
                            ))
-- This is a handler function for the GET request method on the HomeR
-- resource pattern. All of your resource patterns are defined in
-- config/routes
--
-- The majority of the code you will write in Yesod lives in these handler
-- functions. You can spread them across multiple files if you are so
-- inclined, or create a single monolithic file.
getHomeR :: Handler Html
getHomeR = do
    webSockets chatApp
    defaultLayout homeWidget

homeWidget = do
        ili <- handlerToWidget isLoggedIn
        master <- getYesod
        aDomId <- newIdent
        setTitle "Mario Chat"
        $(widgetFile "homepage")
    where isLoggedIn = do
            ma <- maybeAuthId
            return $ maybe False (const True) ma


postHomeR :: Handler Html
postHomeR = do
    let handlerName = "postHomeR" :: Text
    defaultLayout homeWidget
