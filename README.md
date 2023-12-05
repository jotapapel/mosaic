🧩 Mosaic is a tiny and versatile transpiler designed to (in theory) seamlessly convert source code written in a custom programming language  into various target programming languages 🧩

The current programming language Mosaic uses is called ``Tile`` and is a superset of Lua, adding various elements from other languages and, in general terms, extending the programming language. Some structures and symbols are different though, for example, the for loop uses words ``for index = 0 to 8 step 2 do`` instead of commas, and the ``<>`` symbol is used to represent a non-equal comparison.

Mosaic also comes with a tiny bundler that packs a modular structure into a single file. 
(credits to [Minipack](https://github.com/ronami/minipack) for the inspo.)

--- Usage

To use the transpiler simply type:
´´´
lua main.lua (Tile file path) [(target Lua file path)|--display] [--ast]
´´´

The ´´--display´´ options prints the transpiled file to the terminal and the ´´--ast´´ option instead generates a JSON file containing the abstract syntax tree.


To use the bundler type:
´´´
lua bundler.lua (main Tile file path) (target Lua file path)
´´´