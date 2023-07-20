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
        placeholder="Enter your address in Hebrew, including house number, and press Enter"
      />
    </div>
  );
}
