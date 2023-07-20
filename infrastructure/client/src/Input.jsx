import React from 'react'

export default function ZIPCodeInputField({input, setInput, onClick}) {
  const handleInputChange = (event) => {
    setInput(event.target.value);
  }

  const handleKeyPress = (event) => {
    if (event.key === 'Enter') {
      onClick(input);
    }
  }

  return (
    <div className={'input-container'}>
      <input
        id="zip-code-input"
        value={input}
        onChange={handleInputChange}
        onKeyPress={handleKeyPress}
      />
    </div>
  );
}
