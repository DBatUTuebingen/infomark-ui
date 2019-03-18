module Components.Tasks.StudentView exposing
    ( Model
    , Msg(..)
    , init
    , update
    , view
    )

{-| The non admin counter part of TaskEditor.
Can be used to upload submissions and view the
public test results.
-}

import Api.Data.Grade exposing (Grade)
import Api.Data.Task exposing (Task)
import Api.Data.TaskRatingResponse exposing (TaskRatingResponse)
import Api.Request.Task as TaskRequests
import Components.CommonElements exposing 
    ( fileUploader
    , inputLabel
    , r1Column
    , r2Column
    , rCollapsable
    , rContainer
    , rRow
    , rRowButton
    , rRowExtraSpacing
    , sliderInputElement
    , PbbState(..)
    , PbbButtonState(..)
    , PbbResultState(..)
    )
import Debounce exposing (Debounce)
import File exposing (File)
import File.Select as Select
import Html exposing (..)
import Html.Events exposing (onClick)
import Http
import Markdown as MD
import Time
import RemoteData exposing (RemoteData(..), WebData)
import SharedState exposing (SharedState, SharedStateUpdate(..))
import Tachyons exposing (classes)
import Tachyons.Classes as TC
import Utils.Styles as Styles
import Utils.Utils exposing (perform)


type Field
    = Rating


type Msg
    = UploadSubmission
    | UploadSubmissionResponse (WebData ())
    | UploadProgress Http.Progress
    | GetCurrentRatingResponse (WebData TaskRatingResponse)
    | GetGradeResponse (WebData Grade) -- Change return type
    | RateTask Field String
    | SendRating Int
    | RateResponse (WebData ())
    | ToggleCollapse
    | GotFiles File (List File)
    | Pick
    | DragEnter
    | DragLeave
    | NoOp
    | DebounceMsg Debounce.Msg


type alias Model =
    { id : Int
    , courseId : Int
    , task : Task
    , gradeResponse : WebData Grade
    , rating : Int
    , submission : Maybe File
    , uploading : WebData ()
    , uploadPercentage : Int
    , uploadDoneTime : Maybe Time.Posix
    , collapse : Bool
    , hover : Bool
    , ratingDebounce : Debounce Int
    }


init : Int -> Task -> ( Model, Cmd Msg )
init courseId task =
    ( { id = task.id
      , courseId = courseId
      , task = task
      , gradeResponse = Loading
      , rating = 0
      , submission = Nothing
      , uploading = NotAsked
      , uploadPercentage = 0
      , uploadDoneTime = Nothing
      , collapse = True
      , hover = False
      , ratingDebounce = Debounce.init
      }
    , Cmd.batch
        [ TaskRequests.taskResultGet courseId task.id GetGradeResponse
        , TaskRequests.taskRatingGet courseId task.id GetCurrentRatingResponse
        ]
    )


debounceConfig : Debounce.Config Msg
debounceConfig =
    { strategy = Debounce.later 2000
    , transform = DebounceMsg
    }


update : SharedState -> Msg -> Model -> ( Model, Cmd Msg, SharedStateUpdate )
update sharedState msg model =
    case msg of
        UploadSubmission ->
            case model.submission of
                Just file ->
                    ( { model | uploading = Loading }, TaskRequests.taskSubmissionPost model.courseId model.id file UploadSubmissionResponse, NoUpdate )

                Nothing -> -- Should never happen. Upload button disabled without a set file
                    ( model, Cmd.none, NoUpdate )

        
        UploadSubmissionResponse (Success _) ->
            ( { model 
                | uploadDoneTime = sharedState.currentTime
                , uploading = Success ()
                }, Cmd.none, NoUpdate )
        
        UploadSubmissionResponse response ->
            let
                newModel = {model | uploading = response}
                finalModel = if not (RemoteData.isLoading newModel.uploading) &&
                    (RemoteData.isSuccess newModel.uploading || 
                        RemoteData.isFailure newModel.uploading) then
                        { newModel | uploadDoneTime = sharedState.currentTime }
                    else
                        newModel
            in
            ( finalModel, Cmd.none, NoUpdate )

        UploadProgress progress ->
            let
                percentage =
                    case progress of
                        Http.Sending p ->
                            Http.fractionSent p

                        _ ->
                            0.0

                prog =
                    if model.uploading == Loading then
                        round <| (100 * percentage )

                    else
                        round <| 0
            in
            ( { model | uploadPercentage = prog }, Cmd.none, NoUpdate )

        GetCurrentRatingResponse (Success rating) ->
            ( { model | rating = rating.own_rating }, Cmd.none, NoUpdate )

        GetCurrentRatingResponse _ ->
            ( model, Cmd.none, NoUpdate )

        GetGradeResponse response ->
            ( model, Cmd.none, NoUpdate )

        RateTask _ rating ->
            let
                toInt =
                    Maybe.withDefault 0 <| String.toInt rating

                ( debounce, cmd ) =
                    Debounce.push debounceConfig toInt model.ratingDebounce
            in
            ( { model | rating = toInt, ratingDebounce = debounce }, cmd, NoUpdate )

        SendRating rating ->
            ( model, TaskRequests.taskRatingPost model.courseId model.id rating RateResponse, NoUpdate )

        RateResponse response ->
            ( model, Cmd.none, NoUpdate )

        ToggleCollapse ->
            ( { model | collapse = not model.collapse }, Cmd.none, NoUpdate )

        GotFiles file files ->
            ( { model | hover = False, submission = Just file }, Cmd.none, NoUpdate )

        Pick ->
            ( model, Select.files [ "application/zip" ] GotFiles, NoUpdate )

        DragEnter ->
            ( { model | hover = True }, Cmd.none, NoUpdate )

        DragLeave ->
            ( { model | hover = False }, Cmd.none, NoUpdate )

        DebounceMsg subMsg ->
            let
                ( debounce, cmd ) =
                    Debounce.update
                        debounceConfig
                        (Debounce.takeLast (\r -> perform <| SendRating r))
                        subMsg
                        model.ratingDebounce
            in
            ( { model | ratingDebounce = debounce }
            , cmd
            , NoUpdate
            )

        NoOp ->
            ( model, Cmd.none, NoUpdate )


view : SharedState -> Model -> Html Msg
view sharedState model =
    rContainer <|
        rCollapsable ("Task " ++ String.fromInt model.task.id)
            model.collapse
            ToggleCollapse
            ( "Show", "Hide" )
            [ rRow <|
                r2Column
                    [ inputLabel "Submission"
                    , fileUploader model.hover model.submission DragEnter DragLeave Pick GotFiles
                    ]
                    [ inputLabel "Results"
                    , displayResults
                        (case model.gradeResponse of
                            Success grade ->
                                grade.public_test_log

                            Loading ->
                                "Loading"

                            _ ->
                                "Undefined"
                        )
                    ]
            , rRow <|
                r1Column <|
                    sliderInputElement
                        { label = "Rating"
                        , value = model.rating
                        , min = 0
                        , max = 5
                        , step = 1
                        , valueLabel =
                            if model.rating == 0 then
                                "Not rated"

                            else
                                String.fromInt model.rating
                        }
                        Rating
                        []
                        RateTask
            , if model.uploading == Loading then
                rRowButton <| PbbProgressBar model.uploadPercentage
            else
                let
                    success = RemoteData.isSuccess model.uploading
                    failure = RemoteData.isFailure model.uploading

                    filesSelected = case model.submission of
                        Just _ -> True
                        Nothing -> False

                    stateShownLongEnough = Maybe.map2 
                        (\up cur ->
                            (Time.posixToMillis cur) - (Time.posixToMillis up) > 1500
                        ) model.uploadDoneTime sharedState.currentTime
                in
                rRowButton <| PbbButton <|
                    if success && stateShownLongEnough == Just False then
                        PbbResult <| PbbSuccess "Success"
                    else if failure && stateShownLongEnough == Just False then
                        PbbResult <| PbbFailure "Failure"
                    else if not filesSelected then
                        PbbDisabled "Upload"
                    else
                        PbbActive "Upload" UploadSubmission
            ]


displayResults : String -> Html msg
displayResults content =
    div [ classes [ TC.pa4, TC.bg_black_10, TC.shadow_5, TC.br3 ] ]
        [ MD.toHtml [ Styles.textStyle ] content
        ]


type alias Error =
    ( Field, String )