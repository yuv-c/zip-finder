import React, { useState } from 'react';
import ToastContainer from './Toast';
import SearchZIPCodes from './SearchZIPCodes';
import './App.css';
import 'react-toastify/dist/ReactToastify.css';

function App() {
  const [isLoading, setIsLoading] = useState(false);  // Define the loading state

  return (
    <div className="App">
      {isLoading && <div className="loading-spinner"></div>}
      <img src={`${process.env.PUBLIC_URL}/israel_post_logo_170x92.png`} alt="Description" />
      <h1>(Not) Israel Post</h1>
      <SearchZIPCodes setIsLoading={setIsLoading} />
      <ToastContainer />
    </div>
  );
}

export default App;
