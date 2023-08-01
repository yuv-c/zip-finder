import React, { useEffect } from 'react'
import { toast } from 'react-toastify';
import { useState } from "react"
import Results from './Results.jsx'
import AddressInputField from './Input.jsx'
import './SearchZIPCodes.css'

const API_URL = 'https://45xdbeisu1.execute-api.eu-central-1.amazonaws.com/prod/zip-api'

function extractAddressParts(address) {
  const addressParts = address.split(',')
  const numberRegex = /\d+/g
  const houseNumber = addressParts[0]?.match(numberRegex)
  const streetName = addressParts[0]?.replace(numberRegex, '')?.trim()
  const cityName = addressParts[1]?.trim()

  return { houseNumber, streetName, cityName }
}

function validateAddress(address) {
  const addressParts = address.split(',')
  if (addressParts.length !== 2) {
    throw new Error('Invalid address format - Please separate city and street with a comma (,)')
  }

  const { houseNumber, streetName, cityName } = extractAddressParts(address)

  if (!houseNumber) throw new Error('Invalid address format - No house number provided')
  if (!streetName) throw new Error('Invalid address format - No street name provided')
  if (!cityName) throw new Error('Invalid address format - No city provided')
}

export default function SearchZIPCodes({ setIsLoading }) {
  const [address, setAddress] = useState([])
  const [results, setResults] = useState([])
  const [toastNoResults, setToastNoResults] = useState(false);

  useEffect(() => {
    setToastNoResults(false);
  }, [address]);

  async function onSearch(address) {
    if (!address || !address.trim()) return

    setIsLoading(true)
    setToastNoResults(false)
    setResults([])

    try {
      validateAddress(address)
    } catch (e) {
      toast.error(e.message)
      setIsLoading(false)
      return
    }

    const { houseNumber, streetName, cityName } = extractAddressParts(address)
    const toastHTML = <div>Searching...<br />Street: {streetName}<br />House Number: {houseNumber}<br />City: {cityName}
    </div>
    toast.info(toastHTML)


    const headers = {
      'Content-Type': 'application/json'
    }

    const body = {
      zip_code: address
    }

    let response;

    try {
      response = await fetch(`${API_URL}`, {
        method: 'POST', headers, body: JSON.stringify(body)
      });

      const json = await response.json();

      if (!response.ok) {
        throw new Error(`Request failed with status code ${response.status} ${json.error ? `and message: ${json.error}` : ''}`);
      }

      setResults(json)
      setToastNoResults(true);
    } catch (e) {
      console.error(e)
      toast.error(e.message)
      setToastNoResults(false);
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="search-container">
      <AddressInputField input={address} setInput={setAddress} onClick={onSearch} />
      <Results results={results} shouldDisplayToast={toastNoResults}
               setShouldDisplayToast={setToastNoResults} />
    </div>
  );
}