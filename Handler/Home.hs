module Handler.Home where

import Import
import Yesod.Form.Bootstrap3 (BootstrapFormLayout (..), renderBootstrap3)
import Text.Julius (RawJS (..))

-- This is a handler function for the GET request method on the HomeR
-- resource pattern. All of your resource patterns are defined in
-- config/routes
--
-- The majority of the code you will write in Yesod lives in these handler
-- functions. You can spread them across multiple files if you are so
-- inclined, or create a single monolithic file.
getHomeR :: Handler Html
getHomeR = do
    let handlerName = "getHomeR" :: Text
    defaultLayout $ do
        let (commentFormId, commentTextareaId, commentListId) = commentIds
        aDomId <- newIdent
        setTitle "Welcome To Yesod!"
        $(widgetFile "homepage")

postHomeR :: Handler Html
postHomeR = do
    let handlerName = "postHomeR" :: Text
    defaultLayout $ do
        let (commentFormId, commentTextareaId, commentListId) = commentIds
        aDomId <- newIdent
        setTitle "Welcome To Yesod!"
        $(widgetFile "homepage")

commentIds :: (Text, Text, Text)
commentIds = ("js-commentForm", "js-createCommentTextarea", "js-commentList")
