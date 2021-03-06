module Routing.Helpers exposing (Route(..), parseUrl, reverseRoute, routeParser)

import Url exposing (Url)
import Url.Parser exposing ((</>))


type Route
    = LoginRoute
    | RegistrationRoute
    | DashboardRoute
    | CoursesRoute
    | CreateCourseRoute
    | EditCourseRoute Int
    | CourseDetailRoute Int
    | CreateSheetRoute Int
    | EditSheetRoute Int Int
    | TermsOfUseRoute
    | CreateMaterialRoute Int
    | EditMaterialRoute Int Int
    | SheetDetailRoute Int Int
    | SubmissionGradingRoute Int Int Int
    | AdminRoute
    | ProfileEditorRoute
    | MailConfirmationRoute String String
    | RequestPasswordResetRoute
    | PasswordResetRoute String String
    | CreateGroupRoute Int
    | EditGroupRoute Int Int
    | MailToUsersRoute Int
    | MailToGroupRoute Int Int
    | MailToCourseRoute Int
    | NotFoundRoute


reverseRoute : Route -> String
reverseRoute route =
    let
        pieces =
            case route of
                LoginRoute ->
                    []

                RegistrationRoute ->
                    [ "registration" ]

                DashboardRoute ->
                    [ "dashboard" ]

                CoursesRoute ->
                    [ "courses" ]

                CreateCourseRoute ->
                    [ "course", "create" ]

                EditCourseRoute id ->
                    [ "course", String.fromInt id, "edit" ]

                CourseDetailRoute id ->
                    [ "course", String.fromInt id ]

                CreateSheetRoute courseId ->
                    [ "course", String.fromInt courseId, "sheet", "create" ]

                EditSheetRoute courseId id ->
                    [ "course", String.fromInt courseId, "sheet", String.fromInt id, "edit" ]

                CreateMaterialRoute courseId ->
                    [ "course", String.fromInt courseId, "material", "create" ]

                EditMaterialRoute courseId id ->
                    [ "course", String.fromInt courseId, "material", String.fromInt id, "edit" ]

                SheetDetailRoute courseId id ->
                    [ "course", String.fromInt courseId, "sheet", String.fromInt id ]

                SubmissionGradingRoute courseId taskId groupId ->
                    [ "course", String.fromInt courseId, "task", String.fromInt taskId, "grade", "group", String.fromInt groupId ]

                AdminRoute ->
                    [ "admin" ]

                TermsOfUseRoute ->
                    [ "terms" ]

                ProfileEditorRoute ->
                    [ "profile" ]

                MailConfirmationRoute mail token ->
                    [ "confirmation", mail, token ]

                RequestPasswordResetRoute ->
                    [ "request_reset" ]

                PasswordResetRoute mail token ->
                    [ "password_reset", mail, token ]

                CreateGroupRoute courseId ->
                    [ "course", String.fromInt courseId, "group", "create" ]

                EditGroupRoute courseId groupId ->
                    [ "course", String.fromInt courseId, "group", String.fromInt groupId, "edit" ]

                MailToUsersRoute userId ->
                    [ "email", "user", String.fromInt userId ]

                MailToGroupRoute courseId groupId ->
                    [ "email", "course", String.fromInt courseId, "group", String.fromInt groupId ]

                MailToCourseRoute courseId ->
                    [ "email", "course", String.fromInt courseId ]

                _ ->
                    []
    in
    "#/" ++ String.join "/" pieces


routeParser =
    Url.Parser.oneOf
        [ Url.Parser.map LoginRoute Url.Parser.top
        , Url.Parser.map RegistrationRoute (Url.Parser.s "registration")
        , Url.Parser.map DashboardRoute (Url.Parser.s "dashboard")
        , Url.Parser.map CoursesRoute (Url.Parser.s "courses")
        , Url.Parser.map CourseDetailRoute (Url.Parser.s "course" </> Url.Parser.int)
        , Url.Parser.map CreateCourseRoute (Url.Parser.s "course" </> Url.Parser.s "create")
        , Url.Parser.map EditCourseRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "edit")
        , Url.Parser.map SheetDetailRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "sheet" </> Url.Parser.int)
        , Url.Parser.map CreateSheetRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "sheet" </> Url.Parser.s "create")
        , Url.Parser.map EditSheetRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "sheet" </> Url.Parser.int </> Url.Parser.s "edit")
        , Url.Parser.map CreateMaterialRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "material" </> Url.Parser.s "create")
        , Url.Parser.map EditMaterialRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "material" </> Url.Parser.int </> Url.Parser.s "edit")
        , Url.Parser.map SubmissionGradingRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "task" </> Url.Parser.int </> Url.Parser.s "grade" </> Url.Parser.s "group" </> Url.Parser.int)
        , Url.Parser.map ProfileEditorRoute (Url.Parser.s "profile")
        , Url.Parser.map AdminRoute (Url.Parser.s "admin")
        , Url.Parser.map MailConfirmationRoute (Url.Parser.s "confirmation" </> Url.Parser.string </> Url.Parser.string)
        , Url.Parser.map RequestPasswordResetRoute (Url.Parser.s "request_reset")
        , Url.Parser.map PasswordResetRoute (Url.Parser.s "password_reset" </> Url.Parser.string </> Url.Parser.string)
        , Url.Parser.map CreateGroupRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "group" </> Url.Parser.s "create")
        , Url.Parser.map TermsOfUseRoute (Url.Parser.s "terms")
        , Url.Parser.map EditGroupRoute (Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "group" </> Url.Parser.int </> Url.Parser.s "edit")
        , Url.Parser.map MailToUsersRoute (Url.Parser.s "email" </> Url.Parser.s "user" </> Url.Parser.int)
        , Url.Parser.map MailToGroupRoute (Url.Parser.s "email" </> Url.Parser.s "course" </> Url.Parser.int </> Url.Parser.s "group" </> Url.Parser.int)
        , Url.Parser.map MailToCourseRoute (Url.Parser.s "email" </> Url.Parser.s "course" </> Url.Parser.int)
        ]


parseUrl : Url -> Route
parseUrl url =
    case url.fragment of
        Nothing ->
            LoginRoute

        Just fragment ->
            { url | path = fragment, fragment = Nothing }
                |> Url.Parser.parse routeParser
                |> Maybe.withDefault NotFoundRoute
