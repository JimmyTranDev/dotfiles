# Conventions

## File structure

## Conventions

### General
1. Don't add obvious comments if the code is self explanatory
1. Don't add unecessary files or folders
1. Don't ask to update the rest of the code after a change, just do it
1. Don't add comments if not necessary, the code should be self explanatory
1. Always refactor repeating components into map or reusable components

### React

#### Code
1. always try to use named functions
2. always export default if it is the main thing
1. prefer to destructure objects if less code

#### Structure
1. Have a src where all the code is
2. configs are in root folder
4. Have all of the components in components folder
3. keep the types of the component in the same folder named types.ts
4. keep the styles of the component in the same folder named styles.ts
5. keep the constants of the component in the same folder named constants.ts
6. keep the utils of the component in the same folder named utils.ts

### Neovim Lua
1. keep functions that can be used in keymaps in ./lua/actions and in a file that makes sense
2. keep helper functions that are used in other functions in ./lua/utils and in a file that makes sense
3. keep core code in ./lua/core and in a file that makes sense
