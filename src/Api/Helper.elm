module Api.Helper exposing (delete, get, patch, post, postImage)

import Http
import Json.Decode as Decode exposing (Decoder)
import RemoteData exposing (RemoteData(..), WebData)
import File exposing (File)


get : String -> (WebData a -> msg) -> Decoder a -> Cmd msg
get url msg decoder =
    Http.request
        { method = "GET"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson (RemoteData.fromResult >> msg) decoder
        , timeout = Nothing
        , tracker = Nothing
        }


post : String -> Http.Body -> (WebData a -> msg) -> Decoder a -> Cmd msg
post url body msg decoder =
    Http.request
        { method = "POST"
        , headers = []
        , url = url
        , body = body
        , expect = Http.expectJson (RemoteData.fromResult >> msg) decoder
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Uploads an single image. You can subscribe to the tracker "image_upload" using 

    type Msg
        = GotProgress Http.Progress
    
    subscriptions : Model -> Sub Msg
    subscriptions model =
        Http.track "image_upload" GotProgress
-}
postImage : String -> File -> (WebData () -> msg) -> Cmd msg
postImage url file msg =
    Http.request
        { method = "POST"
        , headers = []
        , url = url
        , body = Http.fileBody file
        , expect = Http.expectWhatever (RemoteData.fromResult >> msg)
        , timeout = Nothing
        , tracker = Just "image_upload"
        }


patch : String -> Http.Body -> (WebData a -> msg) -> Decoder a -> Cmd msg
patch url body msg decoder =
    Http.request
        { method = "PATCH"
        , headers = []
        , url = url
        , body = body
        , expect = Http.expectJson (RemoteData.fromResult >> msg) decoder
        , timeout = Nothing
        , tracker = Nothing
        }


delete : String -> (WebData a -> msg) -> Decoder a -> Cmd msg
delete url msg decoder =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson (RemoteData.fromResult >> msg) decoder
        , timeout = Nothing
        , tracker = Nothing
        }
