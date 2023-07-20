import './Results.css';
import lodash from 'lodash';

export default function Results({ results }) {
  if (!results || results.length === 0 || results.hits?.total?.value === 0) {
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
      {getTopResults().map(result => (
        <div key={result.zip_code} className="result-item" onClick={() => copyZIPCodeToClipboard(result.zip_code)}>
          <h3>{result.city_name}</h3>
          <p>Street: {result.street_name}</p>
          <p>House Number: {result.house_number}</p>
          <p>Entrance: {result.entrance}</p>
          <p>Document Score: {result.score}</p>
          <p>ZIP Code: {result.zip_code}</p>
        </div>
      ))}
    </div>
  );
}