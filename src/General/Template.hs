{-# LANGUAGE ViewPatterns #-}

module General.Template(runTemplate) where

import System.FilePath.Posix
import Control.Exception.Extra
import Data.Char
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Language.Javascript.Flot as Flot
import qualified Language.Javascript.JQuery as JQuery


libraries =
    [("jquery.js", JQuery.file)
    ,("jquery.flot.js", Flot.file Flot.Flot)
    ,("jquery.flot.stack.js", Flot.file Flot.FlotStack)
    ]

-- | Template Engine. Perform the following replacements on a line basis:
--
-- * <script src="foo"></script> ==> <script>[[foo]]</script>
--
-- * <link href="foo" rel="stylesheet" type="text/css" /> ==> <style type="text/css">[[foo]]</style>
runTemplate :: (FilePath -> IO LBS.ByteString) -> LBS.ByteString -> IO LBS.ByteString
runTemplate ask = lbsMapLinesIO f
    where
        link = LBS.pack "<link href=\""
        script = LBS.pack "<script src=\""

        f x | Just file <- lbsStripPrefix script y = do res <- grab file; return $ LBS.pack "<script>\n" `LBS.append` res `LBS.append` LBS.pack "\n</script>"
            | Just file <- lbsStripPrefix link y = do res <- grab file; return $ LBS.pack "<style type=\"text/css\">\n" `LBS.append` res `LBS.append` LBS.pack "\n</style>"
            | otherwise = return x
            where
                y = LBS.dropWhile isSpace x
                grab = asker . takeWhile (/= '\"') . LBS.unpack

        asker o@(splitFileName -> ("lib/",x)) = case lookup x libraries of
            Just act -> LBS.readFile =<< act
            Nothing -> errorIO $ "Template library, unknown library: " ++ o
        asker x = ask x


-- Perform a mapM on each line and put the result back together again
lbsMapLinesIO :: (LBS.ByteString -> IO LBS.ByteString) -> LBS.ByteString -> IO LBS.ByteString
lbsMapLinesIO f = fmap LBS.unlines . mapM f . LBS.lines


---------------------------------------------------------------------
-- COMPATIBILITY

-- available in bytestring-0.10.8.0, GHC 8.0 and above
-- alternative implementation below
lbsStripPrefix :: LBS.ByteString -> LBS.ByteString -> Maybe LBS.ByteString
lbsStripPrefix prefix text = if a == prefix then Just b else Nothing
    where (a,b) = LBS.splitAt (LBS.length prefix) text
