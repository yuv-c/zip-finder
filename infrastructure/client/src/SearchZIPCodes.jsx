import React from 'react'
import { useEffect, useState } from "react"
import Results from './Results.jsx'
import ZIPCodeInputField from './Input.jsx'
import './SearchZIPCodes.css'

const API_URL = 'https://45xdbeisu1.execute-api.eu-central-1.amazonaws.com/prod/zip-api'

export default function SearchZIPCodes() {
  const [address, setAddress] = useState([])
  const [results, setResults] = useState([])

  async function onSearch(zipCode) {
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
        throw new Error(`Request failed with status code ${response.status} ${json.error ? `and message ${json.error}` : ''}`);
        // TODO: Toast the error to the UI
      }

      setResults(json)
    } catch (e) {
      console.error(e)
    }
  }

  return (
    <div className="search-container">
      <ZIPCodeInputField input={address} setInput={setAddress} onClick={onSearch} />
      <Results results={results} />
    </div>
  );
}