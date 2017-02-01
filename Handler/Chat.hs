module Handler.Chat where

import Import
import System.Process
import System.IO.Unsafe
import Data.Time
import Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)
import Yesod.WebSockets
import Prelude ((!!))

chatApp :: Int -> WebSocketsT Handler ()
chatApp n = do
    (_ , user) <- lift requireAuthPair
    let name = userIdent user
    sendTextData $ "Welcome, " <> name
    writeChan <- ((!!n) . appChat) <$> getYesod
    readChan <- atomically $ do
        writeTChan writeChan $ name <> " has joined the chat"
        dupTChan writeChan
    race_
        (forever $ atomically (readTChan readChan) >>= sendTextData)
        (sourceWS $$  mapM_C (\msg -> do
                               atomically $ writeTChan writeChan $ name <> ": " <> msg
                               let marioResponse = "#" <> name <> ": " <> (pack . unsafePerformIO $ readProcess "./MarioResponse.sh" [unpack msg, show (n+1)] "")
                               lift (runDB $ do
                                        insert (MessageLog msg (userIdent user) (pack . show . unsafePerformIO $ getZonedTime) (n+1))
                                        insert (MessageLog marioResponse "Mario" (pack . show . unsafePerformIO $ getZonedTime) (n+1)))
                               atomically $ writeTChan writeChan $ "MARIO: " <> marioResponse
                            ))

getChatR :: Int -> Handler Html
getChatR n = do
    webSockets (chatApp n)
    defaultLayout chatWidget

chatWidget = do
        ili <- handlerToWidget isLoggedIn
        master <- getYesod
        aDomId <- newIdent
        setTitle "Mario Chat"
        $(widgetFile "chat")
    where isLoggedIn = do
            ma <- maybeAuthId
            return $ maybe False (const True) ma

postChatR :: Int -> Handler Html
postChatR n = do
    webSockets (chatApp n)
    defaultLayout chatWidget
