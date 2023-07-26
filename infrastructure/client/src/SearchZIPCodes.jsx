import React, { useEffect } from 'react'
import { toast } from 'react-toastify';
import { useState } from "react"
import Results from './Results.jsx'
import AddressInputField from './Input.jsx'
import './SearchZIPCodes.css'

const API_URL = 'https://45xdbeisu1.execute-api.eu-central-1.amazonaws.com/prod/zip-api'

export default function SearchZIPCodes({ setIsLoading }) {
  const [address, setAddress] = useState([])
  const [results, setResults] = useState([])
  const [searchPerformed, setSearchPerformed] = useState(false);


  useEffect(() => {
    setSearchPerformed(false);
  }, [address]);

  async function onSearch(zipCode) {
    setIsLoading(true)
    setResults([])

    const headers = {
      'Content-Type': 'application/json'
    }

    const body = {
      zip_code: zipCode
    }

    let response;

    try {
      response = await fetch(`${API_URL}`, {
        method: 'POST', headers, body: JSON.stringify(body)
      });

      const json = await response.json();

      if (!response.ok) {
        throw new Error(`Request failed with status code ${response.status} ${json.error ? `and message: ${json.error}` : ''}`);
        // TODO: Toast the error to the UI
      }

      setResults(json)
      setSearchPerformed(true);
    } catch (e) {
      console.error(e)
      toast.error(e.message)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="search-container">
      <AddressInputField input={address} setInput={setAddress} onClick={onSearch} />
      <Results results={results} searchPerformed={searchPerformed} />
    </div>
  );
}