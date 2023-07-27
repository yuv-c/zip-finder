import React from 'react';
import { ToastContainer } from 'react-toastify';

export default function Toast (){
  return (
    <>
      <ToastContainer
        position={'bottom-center'}
        autoClose={5000}
        newestOnTop={false}
        closeOnClick
        rtl={false}
        pauseOnFocusLoss
        draggable
        pauseOnHover
        theme={'dark'}
        Bounce
        style={{ width: '80%', justifyContent: 'center', display: 'flex' }}
      />
    </>
  );
};
