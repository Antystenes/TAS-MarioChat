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
        (sourceWS $$ mapM_C (\msg ->
                               atomically $ writeTChan writeChan $ name <> ": " <> msg))

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
    defaultLayout $ do
        ili <- handlerToWidget isLoggedIn
        aDomId <- newIdent
        setTitle "Mario Chat"
        $(widgetFile "homepage")
        if ili
          then do
          -- Logged in: show the widget
            [whamlet|
                <div>
                    <h2>Chat
                    <div #output>
                    <form #form>
                        <input #input type=text placeholder="Enter Message">
            |]
          else do
            -- User isn't logged in, give a not-logged-in message.
            master <- getYesod
            [whamlet|
                <p>
                    You must be #
                    $maybe ar <- authRoute master
                        <a href=@{ar}>logged in
                    $nothing
                        logged in
                    \ to chat.
            |]
    where
          isLoggedIn = do
            ma <- maybeAuthId
            return $ maybe False (const True) ma

postHomeR :: Handler Html
postHomeR = do
    let handlerName = "postHomeR" :: Text
    defaultLayout $ do
        aDomId <- newIdent
        setTitle "Mario Chat"
        $(widgetFile "homepage")
