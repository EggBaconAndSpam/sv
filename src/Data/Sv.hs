{-|
Module      : Data.Sv
Copyright   : (C) CSIRO 2017-2018
License     : BSD3
Maintainer  : George Wilson <george.wilson@data61.csiro.au>
Stability   : experimental
Portability : non-portable

This module exports most of the other modules from the package. It is intended
to be imported unqualified, along with some qualified imports for the
"Data.Sv.Decode" and "Data.Sv.Encode" modules as needed.

@
import Data.Sv
import qualified Data.Sv.Decode as D
import qualified Data.Sv.Encode as E
@
-}

module Data.Sv (
  -- * Decoding
    parseDecode
  , parseDecodeFromFile
  , parseDecodeFromDsvCursor
  , decode
  , decodeMay
  , decodeEither
  , decodeEither'
  , (>>==)
  , (==<<)
  , module Data.Sv.Parse
  , module Data.Sv.Decode.Type
  , module Data.Sv.Decode.Error

  -- * Encoding
  , encode
  , encodeToFile
  , encodeToHandle
  , encodeBuilder
  , encodeRow
  , module Data.Sv.Encode.Type
  , module Data.Sv.Encode.Options

  -- * Structure
  , module Data.Sv.Structure

  -- * Re-exports from contravariant, validation, and semigroupoids
  , Alt (..)
  , Contravariant (..)
  , Divisible (..)
  , divided
  , Decidable (..)
  , chosen
  , Validation (..)
) where

import Control.Monad.IO.Class (MonadIO (liftIO))
import qualified Data.Attoparsec.ByteString.Lazy as AL
import Data.Bifunctor (Bifunctor (first))
import Data.ByteString (ByteString)
import qualified Data.ByteString.UTF8 as UTF8
import qualified Data.ByteString.Lazy as LBS
import HaskellWorks.Data.Dsv.Lazy.Cursor as DSV
import Data.Functor.Alt (Alt (..))
import Data.Functor.Contravariant (Contravariant (..))
import Data.Functor.Contravariant.Divisible (Divisible (..), divided, Decidable (..), chosen)
import Data.Validation (Validation (..))

import Data.Sv.Alien.Cassava (field)
import Data.Sv.Decode
import Data.Sv.Decode.Type
import Data.Sv.Decode.Error
import Data.Sv.Encode
import Data.Sv.Encode.Options
import Data.Sv.Encode.Type
import Data.Sv.Structure
import Data.Sv.Parse

-- | Parse a 'ByteString' as an Sv, and then decode it with the given decoder.
parseDecode ::
  Decode' ByteString a
  -> ParseOptions
  -> LBS.ByteString
  -> DecodeValidation ByteString [a]
parseDecode d opts bs =
  let sep = _separator opts
      cursor = DSV.makeCursor sep bs
  in  parseDecodeFromDsvCursor d opts cursor

-- | Load a file, parse it, and decode it.
parseDecodeFromFile ::
  MonadIO m
  => Decode' ByteString a
  -> ParseOptions
  -> FilePath
  -> m (DecodeValidation ByteString [a])
parseDecodeFromFile d opts fp =
  parseDecode d opts <$> liftIO (LBS.readFile fp)

-- | Decode from a 'DsvCursor'
parseDecodeFromDsvCursor :: Decode' ByteString a -> ParseOptions -> DsvCursor -> DecodeValidation ByteString [a]
parseDecodeFromDsvCursor d opts cursor =
  let toField = Prelude.either badParse pure . parse
      parse = first UTF8.fromString . AL.eitherResult . AL.parse field
  in  flip bindValidation (decode d) . traverse (traverse toField) . DSV.toListVector $ case _headedness opts of
        Unheaded -> cursor
        Headed   -> nextPosition (nextRow cursor)