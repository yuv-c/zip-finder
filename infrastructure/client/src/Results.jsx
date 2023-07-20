import './Results.css';
import lodash from 'lodash';

export default function Results({ results }) {
  if (!results || results.length === 0) {
    return <></>
  }
  console.log(`Rendering results: ${JSON.stringify(results)}`)

  function getTopResults() {
    const hits = lodash.get(results, 'hits.hits', []);
    return hits.map(hit => hit._source);
  }

  return (
    <div className="results-container">
      {getTopResults().map((result, index) => (
        <div key={index} className="result-item">
          <h2>{result.city_name}</h2>
          <p>Street: {result.street_name}</p>
          <p>House Number: {result.house_number}</p>
          <p>Entrance: {result.entrance}</p>
          <p>ZIP Code: {result.zip_code}</p>
        </div>
      ))}
    </div>
  );
}