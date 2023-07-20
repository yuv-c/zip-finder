import SearchZIPCodes from './SearchZIPCodes';
import './App.css';

function App() {
  return (
    <div className="App">
      <img src={`${process.env.PUBLIC_URL}/israel_post_logo_170x92.png`} alt="Description" />
      <h1>(Not) Israel Post</h1>
      <SearchZIPCodes />
    </div>
  );
}

export default App;
