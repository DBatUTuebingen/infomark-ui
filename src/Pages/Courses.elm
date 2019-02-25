{-
   This is the course site. Here, all courses are listed.
       - New courses can be created/edited/deleted by root users.
       - Users can enroll in a course
       - Users can disenroll from the course
       - Courses are split between current and past (archive)
-}


module Pages.Courses exposing (Model, Msg(..), init, update, view, viewCoursesHeader, viewRenderCourse)

import Api.Data.AccountEnrollment exposing (AccountEnrollment)
import Api.Data.Course exposing (Course)
import Api.Data.CourseRole exposing (CourseRole(..))
import Api.Data.UserEnrollment exposing (UserEnrollment)
import Api.Request.Account as AccountRequests
import Api.Request.Courses as CoursesRequests
import Browser.Navigation exposing (pushUrl)
import Components.Toasty
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import I18n
import Markdown as MD
import RemoteData exposing (RemoteData(..), WebData)
import Routing.Helpers exposing (Route(..), reverseRoute)
import SharedState exposing (SharedState, SharedStateUpdate(..))
import Tachyons exposing (classes, tachyons)
import Tachyons.Classes as TC
import Task
import Time
import Toasty
import Utils.DateFormatter as DF
import Utils.Styles as Styles
import Utils.Utils exposing (handleLogoutErrors)
import Components.Dialog as Dialog


type alias Model =
    { courseRequest : WebData (List Course)
    , accountEnrollmentsRequest : WebData (List AccountEnrollment)
    , enrollProgress : WebData ()
    , disenrollProgress : WebData ()
    , showArchive : Bool
    , toasties : Toasty.Stack Components.Toasty.Toast
    , deleteDialogState : Dialog.State
    , courseToDelete : Maybe Course
    }


type Msg
    = CoursesResponse (WebData (List Course))
    | AccountEnrollmentsResponse (WebData (List AccountEnrollment))
    | Enroll Course
    | Disenroll Course
    | EnrollResponse (WebData ())
    | DisenrollResponse (WebData ())
    | RequestDelete Course
    | PerformDelete Course
    | DeleteCourseResponse (WebData ())
    | DeleteCourseDialogShown Bool
    | ToggleArchive
    | ToastyMsg (Toasty.Msg Components.Toasty.Toast)
    | NavigateTo Route
    | NoOp


init : ( Model, Cmd Msg )
init =
    ( { courseRequest = Loading
      , accountEnrollmentsRequest = Loading
      , enrollProgress = NotAsked
      , disenrollProgress = NotAsked
      , showArchive = False
      , toasties = Toasty.initialState
      , deleteDialogState = False
      , courseToDelete = Nothing
      }
    , Cmd.batch
        [ AccountRequests.accountEnrollmentGet AccountEnrollmentsResponse
        , CoursesRequests.coursesGet CoursesResponse
        ]
    )


update : SharedState -> Msg -> Model -> ( Model, Cmd Msg, SharedStateUpdate )
update sharedState msg model =
    let
        _ =
            Debug.log "MSG" msg
    in
    case msg of
        CoursesResponse response ->
            updateHandleCourses sharedState model response

        AccountEnrollmentsResponse response ->
            updateHandleAccountEnrollments sharedState model response

        Enroll course ->
            ( model, CoursesRequests.coursesEnrollmentPost course.id EnrollResponse, NoUpdate )

        Disenroll course ->
            ( model, CoursesRequests.coursesEnrollmentDelete course.id DisenrollResponse, NoUpdate )

        EnrollResponse response ->
            updateHandleEnroll sharedState model response

        DisenrollResponse response ->
            updateHandleDisenroll sharedState model response

        RequestDelete course ->
            ( { model 
                | courseToDelete = Just course
                , deleteDialogState = True }, Cmd.none, NoUpdate)

        PerformDelete course ->
            ( model, CoursesRequests.courseDelete course.id DeleteCourseResponse, NoUpdate )

        DeleteCourseResponse response ->
            updateHandleDelete sharedState model response

        NavigateTo route ->
            ( model, pushUrl sharedState.navKey (reverseRoute route), NoUpdate )

        ToggleArchive ->
            ( { model | showArchive = not model.showArchive }, Cmd.none, NoUpdate )

        DeleteCourseDialogShown visible ->
            case visible of
                False -> 
                    ( { model 
                        | deleteDialogState = visible
                        , courseToDelete = Nothing }, Cmd.none, NoUpdate )
                True ->
                    ( { model | deleteDialogState = visible }, Cmd.none, NoUpdate )
            
        ToastyMsg subMsg ->
            let
                ( newModel, newCmd ) =
                    Toasty.update Components.Toasty.config ToastyMsg subMsg model
            in
            ( newModel, newCmd, NoUpdate )

        NoOp ->
            ( model, Cmd.none, NoUpdate )


updateHandleCourses : SharedState -> Model -> WebData (List Course) -> ( Model, Cmd Msg, SharedStateUpdate )
updateHandleCourses sharedState model response =
    case response of
        RemoteData.Success _ ->
            ( { model | courseRequest = response }, Cmd.none, NoUpdate )

        RemoteData.Failure err ->
            handleLogoutErrors model sharedState
                (\e -> -- Differentiate between errros
                    ( { model | courseRequest = response }, Cmd.none, NoUpdate )
                )
                err

        _ ->
            ( { model | courseRequest = response }, Cmd.none, NoUpdate )


updateHandleAccountEnrollments : SharedState -> Model -> WebData (List AccountEnrollment) -> ( Model, Cmd Msg, SharedStateUpdate )
updateHandleAccountEnrollments sharedState model response =
    case response of
        RemoteData.Success _ ->
            ( { model | accountEnrollmentsRequest = response }, Cmd.none, NoUpdate )

        RemoteData.Failure err ->
            handleLogoutErrors model sharedState
                (\e -> -- Differentiate between errros
                    ( { model | accountEnrollmentsRequest = response }, Cmd.none, NoUpdate )
                )
                err

        _ ->
            ( { model | accountEnrollmentsRequest = response }, Cmd.none, NoUpdate )


updateHandleEnroll : SharedState -> Model -> WebData () -> ( Model, Cmd Msg, SharedStateUpdate )
updateHandleEnroll sharedState model response =
    case response of
        RemoteData.Success _ ->
            let
                ( newModel, newCmd ) =
                    ( { model | enrollProgress = response }
                    , AccountRequests.accountEnrollmentGet AccountEnrollmentsResponse
                    )
                        |> addToast (Components.Toasty.Success "Success" "You are now enrolled")
            in
            ( newModel, newCmd, NoUpdate )

        RemoteData.Failure err ->
            handleLogoutErrors model sharedState
                (\e -> -- Differentiate between errros
                    (let
                        ( newModel, newCmd ) =
                            ( { model | enrollProgress = response }, Cmd.none )
                                |> addToast (Components.Toasty.Error "Error" "Failed to enroll")
                    in
                    ( newModel, newCmd, NoUpdate )
                    )
                )
                err
            

        _ ->
            ( { model | enrollProgress = response }, Cmd.none, NoUpdate )


updateHandleDisenroll : SharedState -> Model -> WebData () -> ( Model, Cmd Msg, SharedStateUpdate )
updateHandleDisenroll sharedState model response =
    case response of
        RemoteData.Success _ ->
            let
                ( newModel, newCmd ) =
                    ( { model | disenrollProgress = response }
                    , AccountRequests.accountEnrollmentGet AccountEnrollmentsResponse
                    )
                        |> addToast (Components.Toasty.Success "Success" "You are now disenrolled")
            in
            ( newModel, newCmd, NoUpdate )

        RemoteData.Failure err ->
            handleLogoutErrors model sharedState
                (\e -> -- Differentiate between errros
                    (let
                        ( newModel, newCmd ) =
                            ( { model | disenrollProgress = response }, Cmd.none )
                                |> addToast (Components.Toasty.Error "Error" "Failed to disenroll")
                    in
                    ( newModel, newCmd, NoUpdate )
                    )
                )
                err

        _ ->
            ( { model | disenrollProgress = response }, Cmd.none, NoUpdate )

updateHandleDelete : SharedState -> Model -> WebData () -> ( Model, Cmd Msg, SharedStateUpdate )
updateHandleDelete sharedState model response =
    case response of
        RemoteData.Success _ ->
            let
                ( newModel, newCmd ) =
                    ( { model 
                        | courseToDelete = Nothing
                        , deleteDialogState = False }
                    , CoursesRequests.coursesGet CoursesResponse
                    )
                        |> addToast (Components.Toasty.Success "Success" "You've deleted the course") --TODO this should be that easy. Add a modal dialog
            in
            ( newModel, newCmd, NoUpdate )

        RemoteData.Failure err ->
            handleLogoutErrors model sharedState
                (\e -> -- Differentiate between errros
                    (let
                        ( newModel, newCmd ) =
                            ( model, Cmd.none )
                                |> addToast (Components.Toasty.Error "Error" "Failed to delete")
                    in
                    ( newModel, newCmd, NoUpdate )
                    )
                )
                err

        _ ->
            ( model, Cmd.none, NoUpdate )

view : SharedState -> Model -> Html Msg
view sharedState model =
    let
        translate =
            I18n.get sharedState.translations
    in
    case ( model.courseRequest, model.accountEnrollmentsRequest ) of
        ( Success courses, Success enrollments ) ->
            let
                currentTime =
                    Maybe.withDefault
                        (Time.millisToPosix 0)
                        -- THIS SHOULD NEVER HAPPEN!
                        sharedState.currentTime

                currentCourses =
                    courses
                        |> List.filter
                            (\course ->
                                Time.posixToMillis course.ends_at
                                    |> (<) (Time.posixToMillis currentTime)
                            )
                        |> List.map
                            (\course ->
                                viewRenderCourse sharedState course <|
                                    findEnrollmentForCourse course enrollments
                            )

                oldCourses =
                    courses
                        |> List.filter
                            (\course ->
                                Time.posixToMillis course.ends_at
                                    |> (>) (Time.posixToMillis currentTime)
                            )
                        |> List.map
                            (\course ->
                                viewRenderCourse sharedState course <|
                                    findEnrollmentForCourse course enrollments
                            )

                displayCourseOrNot =
                    if model.showArchive then
                        div
                            [ classes
                                [ TC.flex
                                , TC.flex_wrap
                                , TC.flex_row
                                , TC.justify_start
                                , TC.content_start
                                ]
                            ]
                            oldCourses

                    else
                        text ""

                userRole =
                    Maybe.withDefault { root = False } sharedState.role

                cTemp =
                    [ viewCoursesHeader "Aktuell" False userRole.root model
                    , div
                        [ classes
                            [ TC.flex
                            , TC.flex_wrap
                            , TC.flex_row
                            , TC.justify_start
                            , TC.content_start
                            , TC.cf
                            ]
                        ]
                        currentCourses
                    ]

                content =
                    if List.length oldCourses > 0 then
                        cTemp
                            ++ [ viewCoursesHeader "Archiv" True False model
                               , displayCourseOrNot
                               ]

                    else
                        cTemp
            in
            div [ classes [ TC.db, TC.pv5_l, TC.pv3_m, TC.pv1, TC.ph0_ns, TC.w_100 ] ]
                [ viewDeleteCourseDialog sharedState model
                , Toasty.view Components.Toasty.config Components.Toasty.view ToastyMsg model.toasties
                , div
                    [ classes
                        [ TC.w_75_l
                        , TC.w_100
                        , TC.ph5
                        , TC.ph0_l
                        , TC.center
                        , TC.mw9_ns
                        ]
                    ]
                    content
                ]

        ( _, _ ) ->
            div [ classes [ TC.db, TC.pv5_l, TC.pv3_m, TC.pv1, TC.w_100 ] ] []


viewDeleteCourseDialog : SharedState -> Model -> Html Msg
viewDeleteCourseDialog sharedState model =
    case model.courseToDelete of
        Just course ->
            Dialog.modalDialog div
                [ Styles.dialogOverlayStyle
                ]
                (Dialog.dialog div
                    [ Styles.dialogContainerStyle
                    ]
                    [ div
                        [ classes [ TC.w_100, TC.ph1, TC.bb, TC.bw2, TC.b__black ] ]
                        [ h1 [] [ text "Delete the course?" ] ]
                    , div
                        [ classes [ TC.w_100, TC.mt4 ] ]
                        [ p [ Styles.textStyle ] [ text "Are you sure you want to delete the course? This cannot be undone. The course and everything associated with the course like enrollments are gone."]
                        , div [ classes [ TC.fr, TC.mt3 ] ]
                            [ button
                                [ classes
                                    []
                                , Styles.buttonRedStyle
                                , onClick <| PerformDelete course
                                ]
                                [ text "Delete" ]
                            , button
                                [ classes
                                    [ TC.ml3 ]
                                , Styles.buttonGreenStyle
                                , onClick <| DeleteCourseDialogShown False
                                ]
                                [ text "Cancel" ]
                            ]
                        ]
                    ]
                )
                model.deleteDialogState
                deleteCourseDialogConfig

        Nothing ->
            text ""



viewCoursesHeader : String -> Bool -> Bool -> Model -> Html Msg
viewCoursesHeader lbl toggable creatable model =
    let
        toggleText =
            if model.showArchive then
                text "Hide"

            else
                text "Show"

        toggle =
            if toggable then
                button
                    [ Styles.buttonGreyStyle
                    , classes [ TC.br_pill, TC.ph3, TC.pv3 ]
                    , onClick ToggleArchive
                    ]
                    [ toggleText ]

            else
                text ""

        create =
            if creatable then
                button
                    [ Styles.buttonGreenStyle
                    , classes [ TC.br_pill, TC.ph4, TC.pv3 ]
                    , onClick <| NavigateTo CreateCourseRoute
                    ]
                    [ text "+" ]

            else
                text ""
    in
    div
        [ classes
            [ TC.w_100
            , TC.flex
            , TC.flex_row
            , TC.justify_between
            , TC.items_center
            , TC.bb
            , TC.bw2
            ]
        ]
        [ h1 [ Styles.headerStyle ] [ text lbl ]
        , toggle
        , create
        ]


viewRenderCourse : SharedState -> Course -> Maybe AccountEnrollment -> Html Msg
viewRenderCourse sharedState course enrollment =
    -- TODO: Show Disenroll button
    -- TODO: Show edit/delete button
    let
        showButtons =
            case enrollment of
                Nothing ->
                    [ ( "Enroll", Enroll course ) ]

                Just _ ->
                    [ ( "Disenroll", Disenroll course ) -- TODO add a confirm dialog
                    , ( "Show", NavigateTo <| CourseDetailRoute course.id )
                    ]

        buttonsHtml =
            List.map
                (\( buttonText, buttonMsg ) ->
                    button
                        [ Styles.buttonGreyStyle
                        , classes [ TC.w_100, TC.mt3 ]
                        , onClick buttonMsg
                        ]
                        [ text buttonText ]
                )
                showButtons

        showAdminButtons =
            case sharedState.role of
                Just ({ root }) ->
                    if root then
                        [ div []
                            [ input 
                                [ type_ "image"
                                , src "assets/pencil.svg" 
                                , classes [ TC.ml2, TC.w2, TC.h2, TC.pa1, TC.dim ]
                                , onClick <| NavigateTo <| EditCourseRoute course.id
                                ]
                                []
                            , input 
                                [ type_ "image"
                                , src "assets/delete.svg" 
                                , classes [ TC.ml2, TC.w2, TC.h2, TC.pa1, TC.dim ]
                                , onClick <| RequestDelete course
                                ]
                                []
                            ]
                        ]
                    else 
                        []

                _ -> []
    in
    article [ classes [ TC.cf, TC.fl, TC.ph3, TC.pv5, TC.w_100, TC.w_50_m, TC.w_third_ns ] ]
        [ header [ classes [ TC.measure ] ]
            [ div[ classes [TC.flex, TC.w_100, TC.justify_between, TC.items_center ] ] <|
                [ h1 [ Styles.listHeadingStyle ] [ text course.name ] -- Bold header
                ] ++ showAdminButtons
            , dl [ Styles.dateStyle ]
                [ dt [ classes [ TC.black, TC.fw6 ] ] [ text "Beginn " ]
                , dd [ classes [ TC.ml0 ] ] [ DF.fullDateFormatter sharedState course.begins_at ]
                , dt [ classes [ TC.black, TC.fw6 ] ] [ text " Ende " ]
                , dd [ classes [ TC.ml0 ] ] [ DF.fullDateFormatter sharedState course.ends_at ]
                ]
            ]
        , div [ classes [ TC.measure ] ] <|
            [ MD.toHtml [ Styles.textStyle ] <| Maybe.withDefault "" course.description -- Normal paragraph
            ]
                ++ buttonsHtml
        ]


findEnrollmentForCourse : Course -> List AccountEnrollment -> Maybe AccountEnrollment
findEnrollmentForCourse course enrollments =
    enrollments
        |> List.filter (\enrollment -> enrollment.course_id == course.id)
        |> List.head


addToast : Components.Toasty.Toast -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
addToast toast ( model, cmd ) =
    Toasty.addToastIfUnique Components.Toasty.config ToastyMsg toast ( model, cmd )


deleteCourseDialogConfig : Dialog.Config Msg
deleteCourseDialogConfig =
    Dialog.Config
        Styles.dialogVisibleStyle
        Styles.dialogGoneStyle
        DeleteCourseDialogShown
        True
        NoOp