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
                               lift (runDB $ insert (MessageLog msg (userIdent user)))
                               atomically $ writeTChan writeChan $ name <> ": " <> msg
                            ))

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
