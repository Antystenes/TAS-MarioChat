1.Prerequisites:
    a) Stack
        To install it on unix system all you need to do is:
        curl -sSL https://get.haskellstack.org/ | sh
    b) Mongodb
        Install it however you like, then to start mongodb on linux:
        systemctl start mongodb.service
1.Initiating all dependencies:
    Use:
        stack build
    in project root dir
2.Launching devel server
    Use:
        stack exec -- yesod devel
