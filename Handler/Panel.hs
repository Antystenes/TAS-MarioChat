module Handler.Panel where

import Import
import Data.Monoid

getPanelR :: Handler Html
getPanelR = do
    userList <- (runDB $ selectList [] [])
    let users = mconcat $ map (row . entityVal)(userList :: [Entity User])
    defaultLayout $
      $(widgetFile "panel")
    where row x = do
            let notA = not . userIsAdmin $ x
                name = userIdent x
            [whamlet| <tr>
                        <th .tabElem> #{name}
                        $if notA
                          <th .tabElem>
                            <form method=post action=@{UserDelete name}>
                              <button type="submit" > Usuń
                        $else
                          <th .tabElem .adminEl> Administrator|]
          --table :: Handler Html -> Handler Html
