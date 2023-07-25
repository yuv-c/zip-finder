import './Results.css';
import lodash from 'lodash';
import { useEffect, useMemo } from "react";
import { toast } from "react-toastify";

export default function Results({ results, searchPerformed }) {
  const areResultsEmpty = results.hits?.total?.value === 0

  useEffect(() => {
  if (areResultsEmpty && searchPerformed) {
    toast.info('No results found');
  }
}, [areResultsEmpty, searchPerformed]);


  if (results.hits?.total?.value === 0) {
    return <></>
  }
  console.log(`Rendering results: ${JSON.stringify(results)}`)

  function getTopResults() {
    const hits = lodash.get(results, 'hits.hits', []);
    return hits.map(hit => {
      hit._source.score = hit._score;
      return hit._source;
    });
  }

  function copyZIPCodeToClipboard(zipCode) {
    if (zipCode) {
      navigator.clipboard.writeText(zipCode)
      // TODO: toast the success to the UI
    }
  }

  return (
    <div className="results-container open">
      <table>
        <thead>
        <tr>
          <th>City</th>
          <th>Street</th>
          <th>House Number</th>
          <th>Document Score</th>
          <th>ZIP Code</th>
        </tr>
        </thead>
        <tbody>
        {getTopResults().map(result => (
          <tr key={result.zip_code} onClick={() => copyZIPCodeToClipboard(result.zip_code)}>
            <td>{result.city_name}</td>
            <td>{result.street_name}</td>
            <td>{result.house_number}</td>
            <td>{result.score}</td>
            <td>{result.zip_code}</td>
          </tr>
        ))}
        </tbody>
      </table>
    </div>
  );
}